import Foundation

/// A collection of macOS virtual keycodes.
/// These constants map to the virtual keycodes defined in Carbon's Events.h
/// (HIToolbox framework) and are represented as UInt16.
public enum KeyCodes {
 // Alphanumeric keys
 public static let a: UInt16 = 0x00
 public static let s: UInt16 = 0x01
 public static let d: UInt16 = 0x02
 public static let f: UInt16 = 0x03
 public static let h: UInt16 = 0x04
 public static let g: UInt16 = 0x05
 public static let z: UInt16 = 0x06
 public static let x: UInt16 = 0x07
 public static let c: UInt16 = 0x08
 public static let v: UInt16 = 0x09
 public static let b: UInt16 = 0x0B
 public static let q: UInt16 = 0x0C
 public static let w: UInt16 = 0x0D
 public static let e: UInt16 = 0x0E
 public static let r: UInt16 = 0x0F
 public static let y: UInt16 = 0x10
 public static let t: UInt16 = 0x11
 public static let one: UInt16 = 0x12
 public static let two: UInt16 = 0x13
 public static let three: UInt16 = 0x14
 public static let four: UInt16 = 0x15
 public static let six: UInt16 = 0x16
 public static let five: UInt16 = 0x17
 public static let equal: UInt16 = 0x18
 public static let nine: UInt16 = 0x19
 public static let seven: UInt16 = 0x1A
 public static let minus: UInt16 = 0x1B
 public static let eight: UInt16 = 0x1C
 public static let zero: UInt16 = 0x1D
 public static let rightBracket: UInt16 = 0x1E
 public static let o: UInt16 = 0x1F
 public static let u: UInt16 = 0x20
 public static let leftBracket: UInt16 = 0x21
 public static let i: UInt16 = 0x22
 public static let p: UInt16 = 0x23
 public static let l: UInt16 = 0x25
 public static let j: UInt16 = 0x26
 public static let quote: UInt16 = 0x27
 public static let k: UInt16 = 0x28
 public static let semicolon: UInt16 = 0x29
 public static let slash: UInt16 = 0x2A
 public static let comma: UInt16 = 0x2B
 public static let backslash: UInt16 = 0x2C
 public static let n: UInt16 = 0x2D
 public static let m: UInt16 = 0x2E
 public static let period: UInt16 = 0x2F
 public static let grave: UInt16 = 0x32

 // Layout-independent keys
 public static let returnKey: UInt16 = 0x24
 public static let tab: UInt16 = 0x30
 public static let space: UInt16 = 0x31
 public static let delete: UInt16 = 0x33
 public static let escape: UInt16 = 0x35
 public static let command: UInt16 = 0x37
 public static let shift: UInt16 = 0x38
 public static let capsLock: UInt16 = 0x39
 public static let option: UInt16 = 0x3A
 public static let control: UInt16 = 0x3B
 public static let rightShift: UInt16 = 0x3C
 public static let rightOption: UInt16 = 0x3D
 public static let rightControl: UInt16 = 0x3E
 public static let function: UInt16 = 0x3F
 public static let volumeUp: UInt16 = 0x48
 public static let volumeDown: UInt16 = 0x49
 public static let mute: UInt16 = 0x4B

 // Numeric Keypad
 public static let keypadDecimal: UInt16 = 0x41
 public static let keypadMultiply: UInt16 = 0x43
 public static let keypadPlus: UInt16 = 0x45
 public static let keypadClear: UInt16 = 0x47
 public static let keypadDivide: UInt16 = 0x4B
 public static let keypadEnter: UInt16 = 0x4C
 public static let keypadMinus: UInt16 = 0x4E
 public static let keypadEquals: UInt16 = 0x51
 public static let keypad0: UInt16 = 0x52
 public static let keypad1: UInt16 = 0x53
 public static let keypad2: UInt16 = 0x54
 public static let keypad3: UInt16 = 0x55
 public static let keypad4: UInt16 = 0x56
 public static let keypad5: UInt16 = 0x57
 public static let keypad6: UInt16 = 0x58
 public static let keypad7: UInt16 = 0x59
 public static let keypad8: UInt16 = 0x5B
 public static let keypad9: UInt16 = 0x5C

 // Function keys
 public static let f1: UInt16 = 0x7A
 public static let f2: UInt16 = 0x78
 public static let f3: UInt16 = 0x63
 public static let f4: UInt16 = 0x76
 public static let f5: UInt16 = 0x60
 public static let f6: UInt16 = 0x61
 public static let f7: UInt16 = 0x62
 public static let f8: UInt16 = 0x64
 public static let f9: UInt16 = 0x65
 public static let f10: UInt16 = 0x6D
 public static let f11: UInt16 = 0x67
 public static let f12: UInt16 = 0x6F
 public static let f13: UInt16 = 0x69
 public static let f14: UInt16 = 0x6B
 public static let f15: UInt16 = 0x71
 public static let f16: UInt16 = 0x6A
 
 // Help and Navigation
 public static let help: UInt16 = 0x72
 public static let home: UInt16 = 0x73
 public static let pageUp: UInt16 = 0x74
 public static let forwardDelete: UInt16 = 0x75
 public static let end: UInt16 = 0x77
 public static let pageDown: UInt16 = 0x79

 // Cursor control keys
 public static let leftArrow: UInt16 = 0x7B
 public static let rightArrow: UInt16 = 0x7C
 public static let downArrow: UInt16 = 0x7D
 public static let upArrow: UInt16 = 0x7E
}

// Extension to map code to readable key names
extension KeyCodes {
    public static func name(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0x00: return "A"
        case 0x01: return "S"
        case 0x02: return "D"
        case 0x03: return "F"
        case 0x04: return "H"
        case 0x05: return "G"
        case 0x06: return "Z"
        case 0x07: return "X"
        case 0x08: return "C"
        case 0x09: return "V"
        case 0x0B: return "B"
        case 0x0C: return "Q"
        case 0x0D: return "W"
        case 0x0E: return "E"
        case 0x0F: return "R"
        case 0x10: return "Y"
        case 0x11: return "T"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x16: return "6"
        case 0x17: return "5"
        case 0x18: return "="
        case 0x19: return "9"
        case 0x1A: return "7"
        case 0x1B: return "-"
        case 0x1C: return "8"
        case 0x1D: return "0"
        case 0x1E: return "]"
        case 0x1F: return "O"
        case 0x20: return "U"
        case 0x21: return "["
        case 0x22: return "I"
        case 0x23: return "P"
        case 0x25: return "L"
        case 0x26: return "J"
        case 0x27: return "'"
        case 0x28: return "K"
        case 0x29: return ";"
        case 0x2A: return "/"
        case 0x2B: return ","
        case 0x2C: return "\\"
        case 0x2D: return "N"
        case 0x2E: return "M"
        case 0x2F: return "."
        case 0x32: return "`"
        
        case 0x24: return "Enter ↩"
        case 0x30: return "Tab ⇥"
        case 0x31: return "Space ␣"
        case 0x33: return "Delete "
        case 0x35: return "Escape "
        case 0x37: return "Cmd "
        case 0x38: return "Shift ⇧"
        case 0x39: return "Caps ⇪"
        case 0x3A: return "Option "
        case 0x3B: return "Ctrl "
        
        case 0x7B: return "Left ◀"
        case 0x7C: return "Right ▶"
        case 0x7D: return "Down ▼"
        case 0x7E: return "Up ▲"
        
        case 1000: return "Left Click"
        case 1001: return "Right Click"
        case 1002: return "Middle Click"
        
        default: return "Key 0x\(String(format: "%02X", keyCode))"
        }
    }
}
