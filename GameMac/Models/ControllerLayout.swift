import Foundation

public struct ControllerLayout: Codable {
    public let layoutKey: String
    public let deviceName: String
    public var axisMap: [Int: String]
    public var buttonMap: [Int: String]

    public init(layoutKey: String, deviceName: String, axisMap: [Int: String], buttonMap: [Int: String]) {
        self.layoutKey = layoutKey
        self.deviceName = deviceName
        self.axisMap = axisMap
        self.buttonMap = buttonMap
    }
}
