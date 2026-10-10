import Foundation

/// Provides built-in default profile structures.
public struct DefaultProfiles {
 /// Default FPS Shooter profile:
 /// - Left Stick: W/A/S/D
 /// - Button A: Space
 /// - Button B: Left Shift
 /// - Button X: R
 /// - Right Trigger (RT): Left Click (coded as 1000)
 /// - Left Trigger (LT): Right Click (coded as 1001)
 /// - Start: Escape
 /// - Select: Tab
 public static let fpsShooter = MappingProfile(
 profileName: "FPS Shooter",
 buttonMapping: [
 "leftStickUp": KeyCodes.w, // W (13)
 "leftStickDown": KeyCodes.s, // S (1)
 "leftStickLeft": KeyCodes.a, // A (0)
 "leftStickRight": KeyCodes.d, // D (2)
 "buttonA": KeyCodes.space, // Space (49)
 "buttonB": KeyCodes.shift, // Left Shift (56)
 "buttonX": KeyCodes.r, // R (15)
 "rightTriggerButton": 1000, // Left Click Custom Code
 "leftTriggerButton": 1001, // Right Click Custom Code
 "start": KeyCodes.escape, // Escape (53)
 "select": KeyCodes.tab // Tab (48)
 ],
 deadZone: 0.15,
 mouseSensitivity: 1.5,
 mouseExponent: 1.2
 )
 
 /// Default Platformer profile:
 /// - Left Stick & D-Pad: Arrow Keys
 /// - Button A: Z
 /// - Button B: X
 /// - Button X: A
 /// - Button Y: S
 /// - Select: Escape
 /// - Start: Return (Enter)
 public static let platformer = MappingProfile(
 profileName: "Platformer",
 buttonMapping: [
 "leftStickUp": KeyCodes.upArrow, // Up Arrow (126)
 "leftStickDown": KeyCodes.downArrow, // Down Arrow (125)
 "leftStickLeft": KeyCodes.leftArrow, // Left Arrow (123)
 "leftStickRight": KeyCodes.rightArrow, // Right Arrow (124)
 "dpadUp": KeyCodes.upArrow,
 "dpadDown": KeyCodes.downArrow,
 "dpadLeft": KeyCodes.leftArrow,
 "dpadRight": KeyCodes.rightArrow,
 "buttonA": KeyCodes.z, // Z (6)
 "buttonB": KeyCodes.x, // X (7)
 "buttonX": KeyCodes.a, // A (0)
 "buttonY": KeyCodes.s, // S (1)
 "select": KeyCodes.escape, // Escape (53)
 "start": KeyCodes.returnKey // Return (36)
 ],
 deadZone: 0.1,
 mouseSensitivity: 1.0,
 mouseExponent: 1.0
 )

    /// Default RPG (Role-Playing Game) profile:
    /// - Left Stick: W/A/S/D (Movement)
    /// - D-Pad: 1/2/3/4 (Hotbar / Abilities)
    /// - Button A: Space (Jump / Confirm)
    /// - Button B: Left Shift (Dodge / Sprint)
    /// - Button X: E (Interact / Loot)
    /// - Button Y: I (Inventory)
    /// - Left Bumper (LB): Q (Quick Slot / Skill)
    /// - Right Bumper (RB): R (Special Ability)
    /// - Right Trigger (RT): Left Click (coded as 1000 - Primary Action / Attack)
    /// - Left Trigger (LT): Right Click (coded as 1001 - Secondary Action / Block)
    /// - Start: Escape (Pause / Menu)
    /// - Select: M (Map / Journal)
    public static let rpg = MappingProfile(
        profileName: "RPG",
        buttonMapping: [
            "leftStickUp": KeyCodes.w, // W (13)
            "leftStickDown": KeyCodes.s, // S (1)
            "leftStickLeft": KeyCodes.a, // A (0)
            "leftStickRight": KeyCodes.d, // D (2)
            "dpadUp": KeyCodes.one, // 1 (18)
            "dpadRight": KeyCodes.two, // 2 (19)
            "dpadDown": KeyCodes.three, // 3 (20)
            "dpadLeft": KeyCodes.four, // 4 (21)
            "buttonA": KeyCodes.space, // Space (49)
            "buttonB": KeyCodes.shift, // Left Shift (56)
            "buttonX": KeyCodes.e, // E (14)
            "buttonY": KeyCodes.i, // I (34)
            "leftBumper": KeyCodes.q, // Q (12)
            "rightBumper": KeyCodes.r, // R (15)
            "rightTriggerButton": 1000, // Left Click Custom Code
            "leftTriggerButton": 1001, // Right Click Custom Code
            "start": KeyCodes.escape, // Escape (53)
            "select": KeyCodes.m // M (46)
        ],
        deadZone: 0.15,
        mouseSensitivity: 1.2,
        mouseExponent: 1.1
    )
    
    /// All default profiles
    public static let all: [MappingProfile] = [fpsShooter, platformer, rpg]
}
