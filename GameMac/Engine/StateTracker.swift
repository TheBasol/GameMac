import Foundation
import os

/// Tracks currently pressed virtual keycodes in a thread-safe set.
/// Prevents redundant key-repeat injections and exposes a flush mechanism to release all stuck keys.
@available(macOS 13.0, *)
public final class StateTracker {
 public static let shared = StateTracker()
 
 private let lock = OSAllocatedUnfairLock(initialState: Set<UInt16>())
 
 public init() {}
 
 /// Tracks a key down event. If the key is not already down, it posts the event and adds it to the tracked set.
 /// - Parameter keyCode: The virtual keycode being pressed.
 public func keyDown(_ keyCode: UInt16) {
 var shouldPost = false
 lock.withLock { pressedKeys in
 if !pressedKeys.contains(keyCode) {
 pressedKeys.insert(keyCode)
 shouldPost = true
 }
 }
 
 if shouldPost {
 EventInjector.postKeyDown(keyCode: keyCode)
 }
 }
 
 /// Tracks a key up event. If the key is currently down, it posts the event and removes it from the tracked set.
 /// - Parameter keyCode: The virtual keycode being released.
 public func keyUp(_ keyCode: UInt16) {
 var shouldPost = false
 lock.withLock { pressedKeys in
 if pressedKeys.contains(keyCode) {
 pressedKeys.remove(keyCode)
 shouldPost = true
 }
 }
 
 if shouldPost {
 EventInjector.postKeyUp(keyCode: keyCode)
 }
 }
 
 /// Releases all currently tracked keys by posting keyUp events and clearing the tracked state.
 public func flushAllKeys() {
 var keysToRelease = Set<UInt16>()
 lock.withLock { pressedKeys in
 keysToRelease = pressedKeys
 pressedKeys.removeAll()
 }
 
 for keyCode in keysToRelease {
 EventInjector.postKeyUp(keyCode: keyCode)
 }
 
 if !keysToRelease.isEmpty {
 AppLogger.engine.info("StateTracker flushed \(keysToRelease.count) keys.")
 }
 }
 
 /// Releases all currently tracked keys. Alias for flushAllKeys().
 public func flush() {
 flushAllKeys()
 }
 
 /// Gets the current set of pressed keycodes (for diagnostics or UI).
 public var pressedKeys: Set<UInt16> {
 lock.withLock { $0 }
 }
}
