import Foundation
import CoreGraphics
import ApplicationServices
import os

/// A utility final class to post keyboard and mouse input events using `CGEvent`.
/// All events are posted globally using the HID system state as the source.
public final class EventInjector {
 
 private static let source = CGEventSource(stateID: .hidSystemState)
 
 private init() {} // Prevent instantiation
 
 /// Runs a diagnostic check on accessibility permissions and attempts to post a dummy null event to verify integration.
 /// - Returns: True if permissions are trusted and event creation/posting succeeded.
 @discardableResult
 public static func runDiagnostics() -> Bool {
 let isTrusted = PermissionChecker.shared.checkAccessibility(prompt: false)
 AppLogger.engine.info("EventInjector diagnostics - AXIsProcessTrusted: \(isTrusted)")
 
 guard let source = CGEventSource(stateID: .hidSystemState) else {
 AppLogger.engine.error("EventInjector diagnostics - Failed to create CGEventSource.")
 return false
 }
 
 // A null event has CGEventType = .null by default.
 // Posting this event validates that we can construct and dispatch events without triggering any action.
 guard let nullEvent = CGEvent(source: source) else {
 AppLogger.engine.error("EventInjector diagnostics - Failed to create null CGEvent.")
 return false
 }
 
 nullEvent.post(tap: .cghidEventTap)
 AppLogger.engine.info("EventInjector diagnostics - Posted null event successfully.")
 return isTrusted
 }
 
 /// Posts a virtual key down event.
 /// - Parameter keyCode: The virtual keycode to press down.
 public static func postKeyDown(keyCode: UInt16) {
 guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
 AppLogger.engine.error("Failed to create keyDown event for keyCode: \(keyCode)")
 return
 }
 event.post(tap: .cghidEventTap)
 }
 
 /// Posts a virtual key up event.
 /// - Parameter keyCode: The virtual keycode to release.
 public static func postKeyUp(keyCode: UInt16) {
 guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
 AppLogger.engine.error("Failed to create keyUp event for keyCode: \(keyCode)")
 return
 }
 event.post(tap: .cghidEventTap)
 }
 
 /// Posts an absolute mouse move event.
 /// - Parameter point: The target screen coordinate to warp the cursor to.
 public static func postAbsoluteMouseMove(to point: CGPoint) {
 guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else {
 AppLogger.engine.error("Failed to create mouseMoved event for absolute position: \(point.x), \(point.y)")
 return
 }
 event.post(tap: .cghidEventTap)
 }
 
 /// Posts a relative mouse move event by sending delta updates.
 /// - Parameters:
 /// - dx: The change in horizontal position.
 /// - dy: The change in vertical position.
 public static func postRelativeMouseMove(dx: CGFloat, dy: CGFloat) {
 let currentPos = CGEvent(source: nil)?.location ?? .zero
 guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: currentPos, mouseButton: .left) else {
 AppLogger.engine.error("Failed to create mouseMoved event for relative movement")
 return
 }
 event.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
 event.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
 event.post(tap: .cghidEventTap)
 }
 
 /// Posts a mouse button event.
 /// - Parameters:
 /// - button: The target mouse button (.left, .right, or .center).
 /// - eventType: The type of mouse event (e.g. .leftMouseDown, .leftMouseUp, .rightMouseDown, etc.).
 /// - clickCount: The click count (e.g. 1 for single click, 2 for double click).
 public static func postMouseButtonEvent(button: CGMouseButton, eventType: CGEventType, clickCount: Int64) {
 let currentPos = CGEvent(source: nil)?.location ?? .zero
 guard let event = CGEvent(mouseEventSource: source, mouseType: eventType, mouseCursorPosition: currentPos, mouseButton: button) else {
 AppLogger.engine.error("Failed to create mouseButtonEvent for button: \(button.rawValue), type: \(eventType.rawValue)")
 return
 }
 event.setIntegerValueField(.mouseEventClickState, value: clickCount)
 event.post(tap: .cghidEventTap)
 }
}
