import Foundation

/// A Swift struct representing the state of all gamepad elements.
/// It is Codable, Hashable, and Equatable, and supports default neutral values.
public struct GamepadState: Codable, Hashable, Equatable {
    // Buttons (Boolean states)
    public var buttonA: Bool = false
    public var buttonB: Bool = false
    public var buttonX: Bool = false
    public var buttonY: Bool = false
    public var leftBumper: Bool = false
    public var rightBumper: Bool = false
    public var leftTriggerButton: Bool = false
    public var rightTriggerButton: Bool = false
    public var dpadUp: Bool = false
    public var dpadDown: Bool = false
    public var dpadLeft: Bool = false
    public var dpadRight: Bool = false
    public var start: Bool = false
    public var select: Bool = false
    public var menu: Bool = false
    public var share: Bool = false
    public var home: Bool = false
    
    // Axes (Normalized Double values)
    // Sticks: -1.0 to 1.0, Triggers: 0.0 to 1.0
    public var leftStickX: Double = 0.0
    public var leftStickY: Double = 0.0
    public var rightStickX: Double = 0.0
    public var rightStickY: Double = 0.0
    public var leftTrigger: Double = 0.0
    public var rightTrigger: Double = 0.0
    
    // Connection status
    public var isConnected: Bool = false
    
    /// Default initializer setting everything to neutral values.
    public init() {}
    
    /// Custom initializer allowing setting specific values.
    public init(
        buttonA: Bool = false,
        buttonB: Bool = false,
        buttonX: Bool = false,
        buttonY: Bool = false,
        leftBumper: Bool = false,
        rightBumper: Bool = false,
        leftTriggerButton: Bool = false,
        rightTriggerButton: Bool = false,
        dpadUp: Bool = false,
        dpadDown: Bool = false,
        dpadLeft: Bool = false,
        dpadRight: Bool = false,
        start: Bool = false,
        select: Bool = false,
        menu: Bool = false,
        share: Bool = false,
        home: Bool = false,
        leftStickX: Double = 0.0,
        leftStickY: Double = 0.0,
        rightStickX: Double = 0.0,
        rightStickY: Double = 0.0,
        leftTrigger: Double = 0.0,
        rightTrigger: Double = 0.0,
        isConnected: Bool = false
    ) {
        self.buttonA = buttonA
        self.buttonB = buttonB
        self.buttonX = buttonX
        self.buttonY = buttonY
        self.leftBumper = leftBumper
        self.rightBumper = rightBumper
        self.leftTriggerButton = leftTriggerButton
        self.rightTriggerButton = rightTriggerButton
        self.dpadUp = dpadUp
        self.dpadDown = dpadDown
        self.dpadLeft = dpadLeft
        self.dpadRight = dpadRight
        self.start = start
        self.select = select
        self.menu = menu
        self.share = share
        self.home = home
        self.leftStickX = leftStickX
        self.leftStickY = leftStickY
        self.rightStickX = rightStickX
        self.rightStickY = rightStickY
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.isConnected = isConnected
    }
}
