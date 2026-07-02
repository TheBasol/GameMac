import Foundation

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

    /// Creates a mapping profile.
    public init(
        profileName: String,
        buttonMapping: [String: UInt16],
        deadZone: Double = 0.1,
        mouseSensitivity: Double = 1.0,
        mouseExponent: Double = 1.0
    ) {
        self.profileName = profileName
        self.buttonMapping = buttonMapping
        self.deadZone = deadZone
        self.mouseSensitivity = mouseSensitivity
        self.mouseExponent = mouseExponent
    }
}
