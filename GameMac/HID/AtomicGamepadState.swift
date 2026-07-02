import Foundation
import os

/// A thread-safe wrapper class for `GamepadState` using `OSAllocatedUnfairLock` (macOS 13.0+).
/// As a final class, it allows the HID reader thread and injection thread to safely
/// share and access the same state reference concurrently.
@available(macOS 13.0, *)
public final class AtomicGamepadState {
 private let lock: OSAllocatedUnfairLock<GamepadState>
 
 /// Initializes the atomic state wrapper.
 /// - Parameter initialState: The initial state to set. Defaults to a neutral GamepadState.
 public init(initialState: GamepadState = GamepadState()) {
 self.lock = OSAllocatedUnfairLock(initialState: initialState)
 }
 
 /// Thread-safely reads the current `GamepadState`.
 /// - Returns: A copy of the current state.
 public func read() -> GamepadState {
 lock.withLock { $0 }
 }
 
 /// Thread-safely updates the entire `GamepadState` with a new value.
 /// - Parameter newState: The new gamepad state to set.
 public func write(_ newState: GamepadState) {
 lock.withLock { $0 = newState }
 }
 
 /// Thread-safely updates the gamepad state in-place using a closure.
 /// - Parameter body: A closure that takes the current state as an inout parameter.
 public func update(_ body: (inout GamepadState) -> Void) {
 lock.withLock { body(&$0) }
 }
}
