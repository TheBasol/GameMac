import Foundation
import IOKit.hid

/// A parser helper that inspects raw IOHIDValueRef elements or usage/usagePages,
/// mapping them to a ControllerLayout and updating GamepadState.
public struct HIDInputParser {
    
    /// Notifies the system during gamepad button recording/binding (passes usage page and usage).
    public static var onButtonPressed: ((UInt32, UInt32) -> Void)?
    /// Notifies during binding when an analog trigger crosses the press threshold (page, usage).
    public static var onAxisPressed: ((UInt32, UInt32) -> Void)?
    /// When false, button-press callbacks are suppressed (normal gameplay).
    public static var bindingEnabled = false
    
    private static var lastAxisBindingKey: Int?
    
    public static func elementKey(page: UInt32, usage: UInt32) -> Int {
        Int((page << 16) | usage)
    }
    
    public static func lookupButtonSemantic(layout: ControllerLayout, page: UInt32, usage: UInt32) -> String? {
        let composite = elementKey(page: page, usage: usage)
        if let match = layout.buttonMap[composite] { return match }
        // Legacy: keys 1-11 mean page 0x09 button usages
        if page == 0x09, let match = layout.buttonMap[Int(usage)] { return match }
        return nil
    }
    
    public static func lookupAxisSemantic(layout: ControllerLayout, page: UInt32, usage: UInt32) -> String? {
        let composite = elementKey(page: page, usage: usage)
        if let match = layout.axisMap[composite] { return match }
        // Legacy: keys on Generic Desktop page 0x01 (sticks, standard trigger axes)
        if page == 0x01, let match = layout.axisMap[Int(usage)] { return match }
        return nil
    }
    
    public static func formatElementKey(_ key: Int) -> String {
        if key > 0xFFFF {
            let page = (key >> 16) & 0xFFFF
            let usage = key & 0xFFFF
            return String(format: "0x%04X%04X", page, usage)
        }
        return String(format: "0x09%04X", key)
    }
    
    public static func formatAxisKey(_ key: Int) -> String {
        formatElementKey(key)
    }
    
    /// Clears transient binding state when binding mode ends.
    public static func resetBindingState() {
        lastAxisBindingKey = nil
    }
    
    /// Parses a raw IOHIDValue and updates the GamepadState in-place.
    public static func parse(valueRef: IOHIDValue, layout: ControllerLayout, into state: inout GamepadState) {
        let element = IOHIDValueGetElement(valueRef)
        let usagePage = UInt32(IOHIDElementGetUsagePage(element))
        let usage = UInt32(IOHIDElementGetUsage(element))
        let integerVal = IOHIDValueGetIntegerValue(valueRef)
        
        logBindingDiagnostic(element: element, usagePage: usagePage, usage: usage, integerVal: integerVal)
        
        // Handle Hat Switch (0x39) under Generic Desktop (0x01) specially since it translates into 4 boolean states
        if usagePage == 0x01 && usage == 0x39 {
            if integerVal >= 0 && integerVal <= 7 {
                state.dpadUp = (integerVal == 7 || integerVal == 0 || integerVal == 1)
                state.dpadRight = (integerVal == 1 || integerVal == 2 || integerVal == 3)
                state.dpadDown = (integerVal == 3 || integerVal == 4 || integerVal == 5)
                state.dpadLeft = (integerVal == 5 || integerVal == 6 || integerVal == 7)
            } else {
                state.dpadUp = false
                state.dpadRight = false
                state.dpadDown = false
                state.dpadLeft = false
            }
            return
        }
        
        if let axisKey = lookupAxisSemantic(layout: layout, page: usagePage, usage: usage) {
            if axisKey.contains("Trigger") {
                let norm = normalizeTrigger(element: element, value: integerVal)
                updateStateAxis(key: axisKey, value: norm, into: &state)
                notifyAxisPressIfNeeded(
                    element: element,
                    usagePage: usagePage,
                    usage: usage,
                    normalizedValue: norm
                )
            } else {
                let norm = normalizeAxis(element: element, value: integerVal)
                updateStateAxis(key: axisKey, value: norm, into: &state)
            }
        } else if let buttonKey = lookupButtonSemantic(layout: layout, page: usagePage, usage: usage) {
            // Misc elements mapped as triggers in buttonMap (legacy bad bindings) — treat as analog
            if isTriggerSemantic(buttonKey) && isAnalogTriggerElement(element) {
                let norm = normalizeTrigger(element: element, value: integerVal)
                updateStateTriggerFromButtonKey(key: buttonKey, value: norm, into: &state)
                notifyAxisPressIfNeeded(
                    element: element,
                    usagePage: usagePage,
                    usage: usage,
                    normalizedValue: norm
                )
            } else {
                let isPressed = integerVal != 0
                if isPressed {
                    notifyButtonPressIfNeeded(element: element, usagePage: usagePage, usage: usage, integerVal: integerVal)
                }
                updateStateButton(key: buttonKey, isPressed: isPressed, into: &state)
            }
        } else if bindingEnabled && (usagePage == 0x01 || usagePage == 0x02) && isAnalogTriggerElement(element) {
            let norm = normalizeTrigger(element: element, value: integerVal)
            notifyAxisPressIfNeeded(
                element: element,
                usagePage: usagePage,
                usage: usage,
                normalizedValue: norm
            )
        } else if integerVal != 0 && isButtonElement(element) {
            notifyButtonPressIfNeeded(element: element, usagePage: usagePage, usage: usage, integerVal: integerVal)
        }
    }
    
    private static func isButtonElement(_ element: IOHIDElement) -> Bool {
        let elementType = IOHIDElementGetType(element)
        return elementType == kIOHIDElementTypeInput_Button
            || elementType == kIOHIDElementTypeInput_Misc
    }
    
    private static func isAnalogTriggerElement(_ element: IOHIDElement) -> Bool {
        let elementType = IOHIDElementGetType(element)
        return elementType == kIOHIDElementTypeInput_Axis
            || elementType == kIOHIDElementTypeInput_Misc
    }
    
    private static func isTriggerSemantic(_ key: String) -> Bool {
        key == "leftTriggerButton" || key == "rightTriggerButton"
    }
    
    private static func elementTypeName(_ element: IOHIDElement) -> String {
        switch IOHIDElementGetType(element) {
        case kIOHIDElementTypeInput_Button: return "Button"
        case kIOHIDElementTypeInput_Axis: return "Axis"
        case kIOHIDElementTypeInput_Misc: return "Misc"
        default: return "Other(\(IOHIDElementGetType(element)))"
        }
    }
    
    private static func logBindingDiagnostic(element: IOHIDElement, usagePage: UInt32, usage: UInt32, integerVal: CFIndex) {
        guard bindingEnabled else { return }
        let message = "[HID-DIAG] page=0x\(String(format: "%02X", usagePage)) usage=\(usage) type=\(elementTypeName(element)) val=\(integerVal)"
        AppLogger.hid.debug("\(message)")
        print(message)
    }
    
    private static func notifyButtonPressIfNeeded(element: IOHIDElement, usagePage: UInt32, usage: UInt32, integerVal: CFIndex) {
        guard bindingEnabled, integerVal != 0, isButtonElement(element) else { return }
        onButtonPressed?(usagePage, usage)
    }
    
    private static func notifyAxisPressIfNeeded(
        element: IOHIDElement,
        usagePage: UInt32,
        usage: UInt32,
        normalizedValue: Double
    ) {
        guard bindingEnabled else { return }
        let compositeKey = elementKey(page: usagePage, usage: usage)
        if normalizedValue <= 0.5 {
            if lastAxisBindingKey == compositeKey {
                lastAxisBindingKey = nil
            }
            return
        }
        guard isAnalogTriggerElement(element) else { return }
        guard lastAxisBindingKey != compositeKey else { return }
        lastAxisBindingKey = compositeKey
        onAxisPressed?(usagePage, usage)
    }
    
    private static func updateStateTriggerFromButtonKey(key: String, value: Double, into state: inout GamepadState) {
        switch key {
        case "leftTriggerButton":
            state.leftTrigger = value
            state.leftTriggerButton = value > 0.5
        case "rightTriggerButton":
            state.rightTrigger = value
            state.rightTriggerButton = value > 0.5
        default:
            break
        }
    }
    
    private static func updateStateAxis(key: String, value: Double, into state: inout GamepadState) {
        switch key {
        case "leftStickX":
            state.leftStickX = value
        case "leftStickY":
            state.leftStickY = -value
        case "rightStickX":
            state.rightStickX = value
        case "rightStickY":
            state.rightStickY = -value
        case "leftTrigger":
            state.leftTrigger = value
            state.leftTriggerButton = value > 0.5
        case "rightTrigger":
            state.rightTrigger = value
            state.rightTriggerButton = value > 0.5
        default:
            break
        }
    }
    
    private static func updateStateButton(key: String, isPressed: Bool, into state: inout GamepadState) {
        switch key {
        case "buttonA": state.buttonA = isPressed
        case "buttonB": state.buttonB = isPressed
        case "buttonX": state.buttonX = isPressed
        case "buttonY": state.buttonY = isPressed
        case "leftBumper": state.leftBumper = isPressed
        case "rightBumper": state.rightBumper = isPressed
        case "leftTriggerButton": state.leftTriggerButton = isPressed
        case "rightTriggerButton": state.rightTriggerButton = isPressed
        case "select": state.select = isPressed
        case "start": state.start = isPressed; state.menu = isPressed
        case "menu": state.menu = isPressed
        case "share": state.share = isPressed
        case "home": state.home = isPressed
        case "dpadUp": state.dpadUp = isPressed
        case "dpadDown": state.dpadDown = isPressed
        case "dpadLeft": state.dpadLeft = isPressed
        case "dpadRight": state.dpadRight = isPressed
        default:
            break
        }
    }
    
    private static func normalizeAxis(element: IOHIDElement, value: CFIndex) -> Double {
        var min = IOHIDElementGetLogicalMin(element)
        var max = IOHIDElementGetLogicalMax(element)
        
        let usage = Int(IOHIDElementGetUsage(element))
        let device = IOHIDElementGetDevice(element)
        if let vendorNum = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber,
           let productNum = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber {
            let layoutKey = String(format: "%04X_%04X", vendorNum.intValue, productNum.intValue)
            if let cal = CalibrationManager.shared.getCalibration(layoutKey: layoutKey, usage: usage) {
                min = CFIndex(cal.min)
                max = CFIndex(cal.max)
            }
        }
        
        guard max > min else { return 0.0 }
        let range = Double(max - min)
        let val = Double(value - min)
        return (val / range) * 2.0 - 1.0
    }
    
    private static func normalizeTrigger(element: IOHIDElement, value: CFIndex) -> Double {
        var min = IOHIDElementGetLogicalMin(element)
        var max = IOHIDElementGetLogicalMax(element)
        
        let usage = Int(IOHIDElementGetUsage(element))
        let device = IOHIDElementGetDevice(element)
        if let vendorNum = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber,
           let productNum = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber {
            let layoutKey = String(format: "%04X_%04X", vendorNum.intValue, productNum.intValue)
            if let cal = CalibrationManager.shared.getCalibration(layoutKey: layoutKey, usage: usage) {
                min = CFIndex(cal.min)
                max = CFIndex(cal.max)
            }
        }
        
        if max <= min {
            // GameSir K1 Misc triggers often report a broken descriptor; assume 0–255.
            return Swift.min(Swift.max(Double(value) / 255.0, 0.0), 1.0)
        }
        let range = Double(max - min)
        let val = Double(value - min)
        return val / range
    }
}
