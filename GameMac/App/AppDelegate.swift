import Cocoa

/// The AppDelegate class handling application lifecycle events.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.default.info("GameMac application started.")
        setupSDLEnvironment()
    }
    
    /// Exports the GameSir-K1 mapping for SDL2-based applications (such as Cemu) dynamically during runtime.
    private func setupSDLEnvironment() {
        let mapping = "0300a05e373500005810000051010000,GameSir-K1 Controller for Xbox,a:b0,b:b1,x:b3,y:b4,back:b10,start:b11,guide:b12,leftstick:b8,rightstick:b9,leftshoulder:b6,rightshoulder:b7,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,platform:Mac OS X,"
        
        // 1. Process level
        setenv("SDL_GAMECONTROLLERCONFIG", mapping, 1)
        
        // 2. User graphical session level so external apps like Cemu inherit it
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["setenv", "SDL_GAMECONTROLLERCONFIG", mapping]
        do {
            try task.run()
            AppLogger.default.info("Successfully exported SDL_GAMECONTROLLERCONFIG for external apps.")
        } catch {
            AppLogger.default.error("Failed to run launchctl setenv: \(error.localizedDescription)")
        }
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
