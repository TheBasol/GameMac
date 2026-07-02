import Foundation

public struct DeviceInfo: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let vendorID: Int
    public let productID: Int

    public var layoutKey: String {
        return String(format: "%04X_%04X", vendorID, productID)
    }

    public init(id: UUID = UUID(), name: String, vendorID: Int, productID: Int) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
    }
}
