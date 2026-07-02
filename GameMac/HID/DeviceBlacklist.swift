import Foundation

public enum DeviceBlacklist {
    private static let nativelySupportedVIDs: Set<Int> = [
        0x045E, // Microsoft
        0x054C, // Sony
        0x057E, // Nintendo
        0x05AC  // Apple
    ]
    
    private static let lock = NSLock()

    public static func isNativelySupported(vid: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return nativelySupportedVIDs.contains(vid)
    }

    public static func shouldSkip(vid: Int, userOverrides: Set<Int>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if userOverrides.contains(vid) {
            return false
        }
        return nativelySupportedVIDs.contains(vid)
    }
}
