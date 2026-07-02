import Foundation
import os

/// Parses raw Xbox GIP/XInput USB packets into GamepadState dynamically based on a ControllerLayout.
public struct GIPPacketParser {
    
    // Callback helper to notify the system during gamepad button recording/binding
    public static var onButtonPressed: ((UInt16) -> Void)?
    
    /// Parses a raw data buffer from an interrupt pipe.
    /// - Parameters:
    ///   - buffer: The raw bytes received.
    ///   - length: The size of the packet.
    ///   - layout: The active ControllerLayout defining the bitmask mappings.
    ///   - state: The inout GamepadState to modify.
    public static func parse(buffer: UnsafeMutablePointer<UInt8>, length: Int, layout: ControllerLayout, into state: inout GamepadState) {
        guard length >= 14 else { return }
        
        let msgType = buffer[0]
        guard msgType == 0x20 else { return }
        
        let payloadLen = buffer[3]
        guard length >= Int(payloadLen) + 4 else { return }
        
        // Offset 4 & 5 contain the digital buttons bitmask
        let buttonsLSB = buffer[4]
        let buttonsMSB = buffer[5]
        
        // Combine LSB and MSB into a single 16-bit bitmask
        let combinedButtons = UInt16(buttonsLSB) | (UInt16(buttonsMSB) << 8)
        
        // If we are currently binding/listening for a button press, check if any bit is active
        if combinedButtons != 0, let callback = onButtonPressed {
            for bitIdx in 0..<16 {
                let mask = UInt16(1 << bitIdx)
                if (combinedButtons & mask) != 0 {
                    callback(mask)
                    break
                }
            }
        }
        
        // Reset button states in state struct before applying active mapped layout
        state.buttonA = false
        state.buttonB = false
        state.buttonX = false
        state.buttonY = false
        state.leftBumper = false
        state.rightBumper = false
        state.dpadUp = false
        state.dpadDown = false
        state.dpadLeft = false
        state.dpadRight = false
        state.start = false
        state.select = false
        state.share = false
        state.home = false
        state.leftTriggerButton = false
        state.rightTriggerButton = false
        
        // Map buttons dynamically using the layout buttonMap (where keys are the bitmask values)
        for (bitmask, semanticName) in layout.buttonMap {
            let isPressed = (combinedButtons & UInt16(bitmask)) != 0
            applyButton(semantic: semanticName, pressed: isPressed, to: &state)
        }
        
        // Triggers (Analog triggers are independent from the button bitmask in GIP)
        let ltRaw = UInt16(buffer[6]) | (UInt16(buffer[7]) << 8)
        state.leftTrigger = Double(ltRaw) / 1023.0
        state.leftTriggerButton = state.leftTrigger > 0.5
        
        let rtRaw = UInt16(buffer[8]) | (UInt16(buffer[9]) << 8)
        state.rightTrigger = Double(rtRaw) / 1023.0
        state.rightTriggerButton = state.rightTrigger > 0.5
        
        // Sticks (Axes are normalized using standard Xbox coordinates)
        let lxRaw = Int16(bitPattern: UInt16(buffer[10]) | (UInt16(buffer[11]) << 8))
        state.leftStickX = Double(lxRaw) / 32767.0
        
        let lyRaw = Int16(bitPattern: UInt16(buffer[12]) | (UInt16(buffer[13]) << 8))
        state.leftStickY = Double(lyRaw) / 32767.0
        
        let rxRaw = Int16(bitPattern: UInt16(buffer[14]) | (UInt16(buffer[15]) << 8))
        state.rightStickX = Double(rxRaw) / 32767.0
        
        let ryRaw = Int16(bitPattern: UInt16(buffer[16]) | (UInt16(buffer[17]) << 8))
        state.rightStickY = Double(ryRaw) / 32767.0
    }
    
    private static func applyButton(semantic: String, pressed: Bool, to state: inout GamepadState) {
        switch semantic {
        case "buttonA": state.buttonA = pressed
        case "buttonB": state.buttonB = pressed
        case "buttonX": state.buttonX = pressed
        case "buttonY": state.buttonY = pressed
        case "leftBumper": state.leftBumper = pressed
        case "rightBumper": state.rightBumper = pressed
        case "leftTriggerButton": state.leftTriggerButton = pressed
        case "rightTriggerButton": state.rightTriggerButton = pressed
        case "dpadUp": state.dpadUp = pressed
        case "dpadDown": state.dpadDown = pressed
        case "dpadLeft": state.dpadLeft = pressed
        case "dpadRight": state.dpadRight = pressed
        case "start": state.start = pressed
        case "select": state.select = pressed
        case "share": state.share = pressed
        case "home": state.home = pressed
        default: break
        }
    }
}
