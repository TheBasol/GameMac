import Foundation
import AppKit
import CoreGraphics
import os

/// The mode of operation for the mouse emulator.
public enum MouseMode: Codable {
 /// Normal cursor movement within the main screen boundaries.
 case desktop
 /// Disassociated cursor movement (relative delta injection), useful for first-person games.
 case fps
}

/// Emulates mouse movement based on a gamepad stick.
/// Runs a high-precision DispatchSourceTimer at 120Hz and prevents App Nap.
@available(macOS 13.0, *)
public final class MouseVelocityEngine {
 private let queue = DispatchQueue(label: "com.gamemac.MouseVelocityEngine", qos: .userInteractive)
 private var timer: DispatchSourceTimer?
 private var activityToken: NSObjectProtocol?
 
 // Core parameters (thread-safe synchronization via the serial queue)
 private var _exponent: Double = 1.5
 private var _sensitivity: Double = 15.0
 private var _mode: MouseMode = .desktop
 
 // Gamepad stick inputs (X and Y in range [-1.0, 1.0])
 private var stickX: Double = 0.0
 private var stickY: Double = 0.0
 
 // Cached screen dimensions to prevent main thread blocking during high-frequency ticks
 private var mainScreenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
 private var primaryScreenHeight: CGFloat = 1080
 
 /// The scaling exponent applied to the gamepad stick inputs.
 public var exponent: Double {
 get { queue.sync { _exponent } }
 set { queue.async { self._exponent = newValue } }
 }
 
 /// The sensitivity multiplier applied to the curved speed output.
 public var sensitivity: Double {
 get { queue.sync { _sensitivity } }
 set { queue.async { self._sensitivity = newValue } }
 }
 
 /// The current mouse mode (.desktop or .fps).
 public var mode: MouseMode {
 get { queue.sync { _mode } }
 set { setMode(newValue) }
 }
 
 public init() {
 updateScreenDimensions()
 
 // Listen to screen layout updates on the main runloop
 NotificationCenter.default.addObserver(
 self,
 selector: #selector(screenParametersChanged),
 name: NSApplication.didChangeScreenParametersNotification,
 object: nil
 )
 }
 
 deinit {
 NotificationCenter.default.removeObserver(self)
 stop()
 }
 
 @objc private func screenParametersChanged() {
 updateScreenDimensions()
 }
 
 /// Asynchronously fetches and updates current screen dimensions on the main thread.
 private func updateScreenDimensions() {
 DispatchQueue.main.async { [weak self] in
 guard let self = self else { return }
 if let screen = NSScreen.main {
 self.mainScreenFrame = screen.frame
 }
 if let primary = NSScreen.screens.first {
 self.primaryScreenHeight = primary.frame.height
 }
 }
 }
 
 /// Updates the current analog stick state.
 /// - Parameters:
 /// - x: Stick horizontal value in range [-1.0, 1.0].
 /// - y: Stick vertical value in range [-1.0, 1.0].
 public func updateStickInput(x: Double, y: Double) {
 queue.async { [weak self] in
 self?.stickX = x
 self?.stickY = y
 }
 }
 
 /// Starts the 120Hz update timer and disables App Nap for this activity.
 public func start() {
 queue.async { [weak self] in
 guard let self = self else { return }
 guard self.timer == nil else { return }
 
 // Prevent App Nap to keep the timer firing accurately
 self.activityToken = ProcessInfo.processInfo.beginActivity(
 options: [.userInitiatedAllowingIdleSystemSleep],
 reason: "High-frequency gamepad stick mouse emulation"
 )
 
 let newTimer = DispatchSource.makeTimerSource(queue: self.queue)
 // 120Hz is exactly ~8.333ms interval (1_000_000_000 / 120 nanoseconds)
 newTimer.schedule(deadline: .now(), repeating: .nanoseconds(1_000_000_000 / 120), leeway: .nanoseconds(0))
 newTimer.setEventHandler { [weak self] in
 self?.tick()
 }
 newTimer.resume()
 self.timer = newTimer
 
 AppLogger.engine.info("MouseVelocityEngine started at 120Hz")
 }
 }
 
 /// Stops the update timer and releases App Nap prevention.
 public func stop() {
 queue.sync {
 if let timer = self.timer {
 timer.cancel()
 self.timer = nil
 }
 
 if let token = self.activityToken {
 ProcessInfo.processInfo.endActivity(token)
 self.activityToken = nil
 }
 
 // Re-associate mouse before shutting down if we were in FPS mode
 if self._mode == .fps {
 CGAssociateMouseAndMouseCursorPosition(1)
 }
 
 AppLogger.engine.info("MouseVelocityEngine stopped")
 }
 }
 
 /// Safely changes the mouse mode and manages cursor association.
 private func setMode(_ newMode: MouseMode) {
 queue.async { [weak self] in
 guard let self = self, self._mode != newMode else { return }
 
 if newMode == .fps {
 // Disassociate cursor for games (delivers raw relative movement)
 CGAssociateMouseAndMouseCursorPosition(0)
 AppLogger.engine.info("MouseVelocityEngine changed to FPS mode (cursor disassociated)")
 } else {
 // Warp cursor to the center of the screen before re-associating
 let frame = self.mainScreenFrame
 let center = CGPoint(
 x: frame.origin.x + frame.width / 2.0,
 y: self.primaryScreenHeight - (frame.origin.y + frame.height / 2.0)
 )
 CGWarpMouseCursorPosition(center)
 CGAssociateMouseAndMouseCursorPosition(1)
 AppLogger.engine.info("MouseVelocityEngine changed to Desktop mode (cursor warped to center & re-associated)")
 }
 self._mode = newMode
 }
 }
 
 /// Main 120Hz update tick. Calculates velocity using the exponential curve and injects mouse movements.
 private func tick() {
 let dx = applyCurve(input: stickX, exponent: _exponent, sensitivity: _sensitivity)
 // Gamepad stick positive Y is upwards, macOS mouse coordinates positive Y is downwards
 let dy = -applyCurve(input: stickY, exponent: _exponent, sensitivity: _sensitivity)
 
 guard dx != 0 || dy != 0 else { return }
 
 if _mode == .desktop {
 // Get current mouse cursor position
 let currentPos = CGEvent(source: nil)?.location ?? .zero
 var newPos = CGPoint(x: currentPos.x + dx, y: currentPos.y + dy)
 
 // Clamp coordinates to screen boundaries
 let frame = mainScreenFrame
 let minX = frame.origin.x
 let maxX = frame.origin.x + frame.width
 let minY = primaryScreenHeight - (frame.origin.y + frame.height)
 let maxY = primaryScreenHeight - frame.origin.y
 
 newPos.x = max(minX, min(newPos.x, maxX))
 newPos.y = max(minY, min(newPos.y, maxY))
 
 EventInjector.postAbsoluteMouseMove(to: newPos)
 } else {
 // FPS mode: post relative motion deltas
 EventInjector.postRelativeMouseMove(dx: dx, dy: dy)
 }
 }
 
 /// Computes exponential curve speed: output = sign(input) * pow(abs(input), exponent) * sensitivity
 private func applyCurve(input: Double, exponent: Double, sensitivity: Double) -> CGFloat {
 guard input != 0 else { return 0 }
 let sign = input < 0 ? -1.0 : 1.0
 let output = sign * pow(abs(input), exponent) * sensitivity
 return CGFloat(output)
 }
}
