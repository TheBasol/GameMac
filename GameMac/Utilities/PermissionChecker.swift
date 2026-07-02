import Foundation
import Cocoa
import ApplicationServices
import IOKit.hid

/// A utility class to check and request permissions for Accessibility and Input Monitoring on macOS.
public final class PermissionChecker {
 public static let shared = PermissionChecker()
 
 // Virtual codes for accessibility/TCC checks
 private let kHIDPage_GenericDesktop = 0x01
 private let kHIDUsage_GD_Joystick = 0x04
 
 private init() {}
 
 /// Checks whether the app has Accessibility permissions.
 /// - Parameter prompt: If true, requests OS to show the dialog box prompting the user to authorize accessibility.
 /// - Returns: True if Accessibility is authorized, false otherwise.
 public func checkAccessibility(prompt: Bool = false) -> Bool {
 if prompt {
 let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
 return AXIsProcessTrustedWithOptions(options)
 } else {
 return AXIsProcessTrusted()
 }
 }
 
 /// Checks whether the app has Input Monitoring permission.
 /// Since macOS does not expose a direct API for Input Monitoring status,
 /// this attempts to open an IOHIDManager with a general joystick matching dictionary.
 /// If Input Monitoring is denied, the open call will fail (return non-success).
 /// - Returns: True if Input Monitoring is allowed/trusted, false otherwise.
 public func checkInputMonitoring() -> Bool {
 let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
 let matchingDict = [
 kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
 kIOHIDDeviceUsageKey: kHIDUsage_GD_Joystick
 ] as CFDictionary
 IOHIDManagerSetDeviceMatching(manager, matchingDict)
 
 let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
 if result == kIOReturnSuccess {
 IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
 return true
 }
 return false
 }
 
 /// Opens the System Preferences / Settings panel directly to the Accessibility page.
 public func openAccessibilitySettings() {
 let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
 if let url = URL(string: urlString) {
 NSWorkspace.shared.open(url)
 }
 }
 
 /// Opens the System Preferences / Settings panel directly to the Input Monitoring page.
 public func openInputMonitoringSettings() {
 let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
 if let url = URL(string: urlString) {
 NSWorkspace.shared.open(url)
 }
 }
}
