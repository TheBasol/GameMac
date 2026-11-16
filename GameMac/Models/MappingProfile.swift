import Foundation

/// Defines how an analog stick's motion is translated by the input mapper.
public enum StickInputMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case keyboard = "Keyboard"
    case mouse = "Mouse"
    case disabled = "Disabled"

    public var id: String { rawValue }
}

/// A representation of a gamepad-to-keyboard/mouse mapping configuration.
public struct MappingProfile: Codable, Equatable, Hashable {
    /// The user-facing name of the profile.
    public var profileName: String
    
    /// A dictionary mapping gamepad button names (e.g. "buttonA", "leftStickUp") to macOS virtual keycodes.
    public var buttonMapping: [String: UInt16]
    
    /// The deadzone value for analog sticks (typically 0.0 to 1.0).
    public var deadZone: Double
    
    /// The multiplier applied to mouse cursor movement speed.
    public var mouseSensitivity: Double
    
    /// The exponent applied to stick deflection for non-linear mouse response curve.
    public var mouseExponent: Double

    /// Whether mouse emulation uses FPS raw relative delta mode instead of Desktop screen cursor mode.
    public var isFpsMode: Bool

    /// Behavior mode for the left analog stick.
    public var leftStickMode: StickInputMode

    /// Behavior mode for the right analog stick.
    public var rightStickMode: StickInputMode

    enum CodingKeys: String, CodingKey {
        case profileName
        case buttonMapping
        case deadZone
        case mouseSensitivity
        case mouseExponent
        case isFpsMode
        case leftStickMode
        case rightStickMode
    }

    /// Creates a mapping profile.
    public init(
        profileName: String,
        buttonMapping: [String: UInt16],
        deadZone: Double = 0.1,
        mouseSensitivity: Double = 1.0,
        mouseExponent: Double = 1.0,
        isFpsMode: Bool = false,
        leftStickMode: StickInputMode? = nil,
        rightStickMode: StickInputMode? = nil
    ) {
        self.profileName = profileName
        self.buttonMapping = buttonMapping
        self.deadZone = deadZone
        self.mouseSensitivity = mouseSensitivity
        self.mouseExponent = mouseExponent
        self.isFpsMode = isFpsMode
        self.leftStickMode = leftStickMode ?? Self.inferredLeftStickMode(from: buttonMapping)
        self.rightStickMode = rightStickMode ?? Self.inferredRightStickMode(from: buttonMapping)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mapping = try container.decodeIfPresent([String: UInt16].self, forKey: .buttonMapping) ?? [:]
        self.profileName = try container.decode(String.self, forKey: .profileName)
        self.buttonMapping = mapping
        self.deadZone = try container.decodeIfPresent(Double.self, forKey: .deadZone) ?? 0.15
        self.mouseSensitivity = try container.decodeIfPresent(Double.self, forKey: .mouseSensitivity) ?? 1.5
        self.mouseExponent = try container.decodeIfPresent(Double.self, forKey: .mouseExponent) ?? 1.2
        self.isFpsMode = try container.decodeIfPresent(Bool.self, forKey: .isFpsMode) ?? false
        self.leftStickMode = try container.decodeIfPresent(StickInputMode.self, forKey: .leftStickMode)
            ?? Self.inferredLeftStickMode(from: mapping)
        self.rightStickMode = try container.decodeIfPresent(StickInputMode.self, forKey: .rightStickMode)
            ?? Self.inferredRightStickMode(from: mapping)
    }

    private static func inferredLeftStickMode(from mapping: [String: UInt16]) -> StickInputMode {
        let hasLeftKeys = mapping["leftStickUp"] != nil
            || mapping["leftStickDown"] != nil
            || mapping["leftStickLeft"] != nil
            || mapping["leftStickRight"] != nil
        if hasLeftKeys { return .keyboard }
        let hasRightKeys = mapping["rightStickUp"] != nil
            || mapping["rightStickDown"] != nil
            || mapping["rightStickLeft"] != nil
            || mapping["rightStickRight"] != nil
        return hasRightKeys ? .mouse : .disabled
    }

    private static func inferredRightStickMode(from mapping: [String: UInt16]) -> StickInputMode {
        let hasRightKeys = mapping["rightStickUp"] != nil
            || mapping["rightStickDown"] != nil
            || mapping["rightStickLeft"] != nil
            || mapping["rightStickRight"] != nil
        return hasRightKeys ? .keyboard : .mouse
    }
}
