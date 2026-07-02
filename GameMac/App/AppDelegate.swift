import Cocoa

/// The AppDelegate class handling application lifecycle events.
public final class AppDelegate: NSObject, NSApplicationDelegate {
 
 public func applicationDidFinishLaunching(_ notification: Notification) {
 AppLogger.default.info("GameMac application started.")
 }
 
 public func applicationWillTerminate(_ notification: Notification) {
 AppLogger.default.info("GameMac application will terminate. Flushing input states...")
 if #available(macOS 13.0, *) {
 StateTracker.shared.flush()
 } else {
 AppLogger.default.warning("StateTracker is only available on macOS 13.0 or later.")
 }
 }
}
