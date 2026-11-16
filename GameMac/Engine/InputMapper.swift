import Foundation
import CoreGraphics
import os

/// Translates GamepadState into macOS system events based on a MappingProfile.
/// Manages input edge-detection to prevent redundant repeats, and pipes analog sticks to the mouse velocity engine.
@available(macOS 13.0, *)
public final class InputMapper {
 private let atomicState: AtomicGamepadState
 private let stateTracker: StateTracker
 private let mouseEngine: MouseVelocityEngine
 
 /// The profile defining current mappings.
 public var profile: MappingProfile
 
 // Retain previous state to perform edge/transition checks
 private var lastState = GamepadState()
 
 public init(
 atomicState: AtomicGamepadState,
 stateTracker: StateTracker,
 mouseEngine: MouseVelocityEngine,
 profile: MappingProfile
 ) {
 self.atomicState = atomicState
 self.stateTracker = stateTracker
 self.mouseEngine = mouseEngine
 self.profile = profile
 }
 
 /// Reads current gamepad state, evaluates edges on button states, and forwards stick values.
 public func processCurrentState() {
 let currentState = atomicState.read()
 
 // 1. Process Buttons (evaluates pressed/released edges)
 processButton(currentState.buttonA, lastState.buttonA, key: "buttonA")
 processButton(currentState.buttonB, lastState.buttonB, key: "buttonB")
 processButton(currentState.buttonX, lastState.buttonX, key: "buttonX")
 processButton(currentState.buttonY, lastState.buttonY, key: "buttonY")
 
 processButton(currentState.leftBumper, lastState.leftBumper, key: "leftBumper")
 processButton(currentState.rightBumper, lastState.rightBumper, key: "rightBumper")
 processButton(currentState.leftTriggerButton, lastState.leftTriggerButton, key: "leftTriggerButton")
 processButton(currentState.rightTriggerButton, lastState.rightTriggerButton, key: "rightTriggerButton")
 
 processButton(currentState.dpadUp, lastState.dpadUp, key: "dpadUp")
 processButton(currentState.dpadDown, lastState.dpadDown, key: "dpadDown")
 processButton(currentState.dpadLeft, lastState.dpadLeft, key: "dpadLeft")
 processButton(currentState.dpadRight, lastState.dpadRight, key: "dpadRight")
 
 processButton(currentState.start, lastState.start, key: "start")
 processButton(currentState.select, lastState.select, key: "select")
 processButton(currentState.menu, lastState.menu, key: "menu")
 processButton(currentState.share, lastState.share, key: "share")
 processButton(currentState.home, lastState.home, key: "home")
 
 // 2. Process Sticks
 processSticks(currentState: currentState, lastState: lastState)
 
 // 3. Keep track of previous state
 lastState = currentState
 }
 
 /// Translates button state transitions to key/mouse events.
 private func processButton(_ current: Bool, _ last: Bool, key: String) {
 guard current != last else { return }
 guard let keyCode = profile.buttonMapping[key] else { return }
 
 let isPressed = current
 if keyCode == 1000 { // Left Click
 let type: CGEventType = isPressed ? .leftMouseDown : .leftMouseUp
 EventInjector.postMouseButtonEvent(button: .left, eventType: type, clickCount: 1)
 } else if keyCode == 1001 { // Right Click
 let type: CGEventType = isPressed ? .rightMouseDown : .rightMouseUp
 EventInjector.postMouseButtonEvent(button: .right, eventType: type, clickCount: 1)
 } else if keyCode == 1002 { // Center Click
 let type: CGEventType = isPressed ? .otherMouseDown : .otherMouseUp
 EventInjector.postMouseButtonEvent(button: .center, eventType: type, clickCount: 1)
 } else {
 if isPressed {
 stateTracker.keyDown(keyCode)
 } else {
 stateTracker.keyUp(keyCode)
 }
 }
 }
 
    private func processSticks(currentState: GamepadState, lastState: GamepadState) {
        // Set mouse engine parameters from the active profile
        mouseEngine.sensitivity = profile.mouseSensitivity * 10.0 // Scale if needed for appropriate velocity
        mouseEngine.exponent = profile.mouseExponent

        let deadZone = profile.deadZone

        // 1. Left Stick -> Keyboard Keys
        if profile.leftStickMode == .keyboard {
            processStickToKeys(
                x: currentState.leftStickX,
                y: currentState.leftStickY,
                lastX: lastState.leftStickX,
                lastY: lastState.leftStickY,
                upKey: profile.buttonMapping["leftStickUp"],
                downKey: profile.buttonMapping["leftStickDown"],
                leftKey: profile.buttonMapping["leftStickLeft"],
                rightKey: profile.buttonMapping["leftStickRight"],
                deadzone: deadZone
            )
        }

        // 2. Right Stick -> Keyboard Keys
        if profile.rightStickMode == .keyboard {
            processStickToKeys(
                x: currentState.rightStickX,
                y: currentState.rightStickY,
                lastX: lastState.rightStickX,
                lastY: lastState.rightStickY,
                upKey: profile.buttonMapping["rightStickUp"],
                downKey: profile.buttonMapping["rightStickDown"],
                leftKey: profile.buttonMapping["rightStickLeft"],
                rightKey: profile.buttonMapping["rightStickRight"],
                deadzone: deadZone
            )
        }

        // 3. Mouse velocity emulation for sticks explicitly assigned to Mouse mode
        let lx = abs(currentState.leftStickX) < deadZone ? 0.0 : currentState.leftStickX
        let ly = abs(currentState.leftStickY) < deadZone ? 0.0 : currentState.leftStickY

        let rx = abs(currentState.rightStickX) < deadZone ? 0.0 : currentState.rightStickX
        let ry = abs(currentState.rightStickY) < deadZone ? 0.0 : currentState.rightStickY

        if profile.rightStickMode == .mouse && (rx != 0.0 || ry != 0.0) {
            mouseEngine.updateStickInput(x: rx, y: ry)
        } else if profile.leftStickMode == .mouse && (lx != 0.0 || ly != 0.0) {
            mouseEngine.updateStickInput(x: lx, y: ly)
        } else {
            mouseEngine.updateStickInput(x: 0.0, y: 0.0)
        }
    }

    private func processStickToKeys(
        x: Double,
        y: Double,
        lastX: Double,
        lastY: Double,
        upKey: UInt16?,
        downKey: UInt16?,
        leftKey: UInt16?,
        rightKey: UInt16?,
        deadzone: Double
    ) {
        let cx = abs(x) < deadzone ? 0.0 : x
        let cy = abs(y) < deadzone ? 0.0 : y

        let lastCx = abs(lastX) < deadzone ? 0.0 : lastX
        let lastCy = abs(lastY) < deadzone ? 0.0 : lastY

        // X-axis updates (Left / Right)
        let isNegX = cx < 0.0
        let lastNegX = lastCx < 0.0
        if isNegX != lastNegX, let leftKey = leftKey {
            if isNegX {
                stateTracker.keyDown(leftKey)
            } else {
                stateTracker.keyUp(leftKey)
            }
        }

        let isPosX = cx > 0.0
        let lastPosX = lastCx > 0.0
        if isPosX != lastPosX, let rightKey = rightKey {
            if isPosX {
                stateTracker.keyDown(rightKey)
            } else {
                stateTracker.keyUp(rightKey)
            }
        }

        // Y-axis updates (Down / Up)
        let isNegY = cy < 0.0
        let lastNegY = lastCy < 0.0
        if isNegY != lastNegY, let downKey = downKey {
            if isNegY {
                stateTracker.keyDown(downKey)
            } else {
                stateTracker.keyUp(downKey)
            }
        }

        let isPosY = cy > 0.0
        let lastPosY = lastCy > 0.0
        if isPosY != lastPosY, let upKey = upKey {
            if isPosY {
                stateTracker.keyDown(upKey)
            } else {
                stateTracker.keyUp(upKey)
            }
        }
    }
}
