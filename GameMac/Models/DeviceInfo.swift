import Foundation

public struct DeviceInfo: Identifiable, Hashable {
    public var id: String { layoutKey }
    public let name: String
    public let vendorID: Int
    public let productID: Int

    public var layoutKey: String {
        return String(format: "%04X_%04X", vendorID, productID)
    }

    public init(name: String, vendorID: Int, productID: Int) {
        self.name = name
        self.vendorID = vendorID
        self.productID = productID
    }
}
