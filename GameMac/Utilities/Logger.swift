import Foundation
import os

/// A utility final class for application-wide logging using `os.Logger` and `OSLog`.
/// Provides dedicated channels for default, hid, engine, and ui subsystems.
public final class AppLogger {
 private static let subsystem = Bundle.main.bundleIdentifier ?? "com.gamemac.app"
 
 // Modern os.Logger instances for Swift logging
 public static let `default` = Logger(subsystem: subsystem, category: "default")
 public static let hid = Logger(subsystem: subsystem, category: "hid")
 public static let engine = Logger(subsystem: subsystem, category: "engine")
 public static let ui = Logger(subsystem: subsystem, category: "ui")
 
 // Classic OSLog instances for use with os_log/C-interoperability if needed
 public static let defaultLog = OSLog(subsystem: subsystem, category: "default")
 public static let hidLog = OSLog(subsystem: subsystem, category: "hid")
 public static let engineLog = OSLog(subsystem: subsystem, category: "engine")
 public static let uiLog = OSLog(subsystem: subsystem, category: "ui")
 
 private init() {} // Prevent instantiation
}
