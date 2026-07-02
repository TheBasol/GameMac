import Foundation
import IOKit.hid
import os

@available(macOS 13.0, *)
public final class HIDGamepadManager {
    private let state: AtomicGamepadState
    private var manager: IOHIDManager?
    private var thread: HIDThread?
    
    // Raw USB Support for non-standard Xbox controllers (like GameSir K1)
    private var rawUSBManager: RawUSBGamepadManager?
    
    public typealias DeviceRemovedCallback = () -> Void
    private let onDeviceRemoved: DeviceRemovedCallback?
    
    // Combined registry of devices (either IOHIDDevice or Raw USB represented by a placeholder key)
    private var hidDevices: [IOHIDDevice: DeviceInfo] = [:]
    private var rawDevices: [String: DeviceInfo] = [:] // Keyed by layoutKey/name
    
    private let deviceLock = NSLock()
    private var _activeDeviceRef: DeviceType = .none
    private var _activeLayout: ControllerLayout?
    
    private enum DeviceType {
        case none
        case hid(IOHIDDevice)
        case raw(String)
    }
    
    public var activeDevice: DeviceInfo? {
        deviceLock.lock()
        defer { deviceLock.unlock() }
        switch _activeDeviceRef {
        case .none:
            return nil
        case .hid(let device):
            return hidDevices[device]
        case .raw(let key):
            return rawDevices[key]
        }
    }
    
    // Safe public getter/setter for the active controller layout
    public var activeLayout: ControllerLayout? {
        get {
            deviceLock.lock()
            defer { deviceLock.unlock() }
            return _activeLayout
        }
        set {
            deviceLock.lock()
            _activeLayout = newValue
            deviceLock.unlock()
        }
    }
    
    public var onConnectedDevicesChanged: (([DeviceInfo]) -> Void)?
    public var onActiveDeviceChanged: ((DeviceInfo?) -> Void)?
    
    // UI-facing callback when a physical HID button is pressed during binding (page, usage)
    public var onHIDButtonPressed: ((UInt32, UInt32) -> Void)?
    // UI-facing callback when a physical HID trigger axis crosses threshold during binding (page, usage)
    public var onHIDAxisPressed: ((UInt32, UInt32) -> Void)?
    // UI-facing callback when a physical GIP button is pressed during binding (bitmask)
    public var onGamepadButtonPressed: ((UInt16) -> Void)?
    
    public init(state: AtomicGamepadState, onDeviceRemoved: DeviceRemovedCallback? = nil) {
        self.state = state
        self.onDeviceRemoved = onDeviceRemoved
        
        // Instantiate the Raw USB Manager
        self.rawUSBManager = RawUSBGamepadManager(state: state) { [weak self] in
            self?.onDeviceRemoved?()
        }
        
        // Wire the layout query dynamically
        self.rawUSBManager?.getActiveLayout = { [weak self] in
            self?.activeLayout
        }
        
        setupRawUSBCallbacks()
    }
    
    deinit {
        stop()
    }
    
    private func setupRawUSBCallbacks() {
        rawUSBManager?.onDeviceMatched = { [weak self] deviceInfo in
            Task { @MainActor in
                self?.rawDeviceMatched(deviceInfo)
            }
        }
        
        rawUSBManager?.onDeviceRemovedCallback = { [weak self] deviceInfo in
            Task { @MainActor in
                self?.rawDeviceRemoved(deviceInfo)
            }
        }
        
        // Redirect physical button presses to UI callbacks (HID and GIP paths)
        HIDInputParser.onButtonPressed = { [weak self] page, usage in
            guard self?.onHIDButtonPressed != nil else { return }
            self?.onHIDButtonPressed?(page, usage)
        }
        HIDInputParser.onAxisPressed = { [weak self] page, usage in
            guard self?.onHIDAxisPressed != nil else { return }
            self?.onHIDAxisPressed?(page, usage)
        }
        GIPPacketParser.onButtonPressed = { [weak self] bitmask in
            self?.onGamepadButtonPressed?(bitmask)
        }
    }
    
    /// Starts both IOHIDManager and RawUSBGamepadManager
    public func start() {
        rawUSBManager?.start()
        
        guard manager == nil else {
            AppLogger.hid.warning("HIDGamepadManager is already running.")
            return
        }
        
        // 1. Create the IOHIDManager instance
        let managerRef = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = managerRef
        
        // 2. Define matching criteria for standard HID controllers
        let joystickMatching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x04
        ]
        let gamepadMatching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x05
        ]
        let multiAxisMatching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: 0x01,
            kIOHIDDeviceUsageKey: 0x08
        ]
        let matchingArray = [joystickMatching, gamepadMatching, multiAxisMatching] as CFArray
        IOHIDManagerSetDeviceMatchingMultiple(managerRef, matchingArray)
        
        // 3. Register callbacks
        let contextPointer = Unmanaged.passUnretained(self).toOpaque()
        
        let matchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
            guard let context = context else { return }
            let instance = Unmanaged<HIDGamepadManager>.fromOpaque(context).takeUnretainedValue()
            instance.deviceMatched(device: device)
        }
        
        let removalCallback: IOHIDDeviceCallback = { context, result, sender, device in
            guard let context = context else { return }
            let instance = Unmanaged<HIDGamepadManager>.fromOpaque(context).takeUnretainedValue()
            instance.deviceRemoved(device: device)
        }
        
        let valueCallback: IOHIDValueCallback = { context, result, sender, value in
            guard let context = context else { return }
            let instance = Unmanaged<HIDGamepadManager>.fromOpaque(context).takeUnretainedValue()
            instance.inputValueReceived(value: value)
        }
        
        IOHIDManagerRegisterDeviceMatchingCallback(managerRef, matchingCallback, contextPointer)
        IOHIDManagerRegisterDeviceRemovalCallback(managerRef, removalCallback, contextPointer)
        IOHIDManagerRegisterInputValueCallback(managerRef, valueCallback, contextPointer)
        
        // 4. Open the IOHIDManager
        let openResult = IOHIDManagerOpen(managerRef, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            AppLogger.hid.error("Failed to open IOHIDManager. IOReturn: \(openResult)")
            return
        }
        
        AppLogger.hid.info("IOHIDManager opened successfully.")
        
        // 5. Run standard HID event loop on its thread
        let hidThread = HIDThread(manager: managerRef)
        self.thread = hidThread
        hidThread.start()
        
        hidThread.waitTillReady()
        AppLogger.hid.info("HID thread started.")
    }
    
    public func stop() {
        rawUSBManager?.stop()
        
        guard let managerRef = manager else { return }
        
        if let hidThread = thread {
            hidThread.stopThread()
            if let runLoop = hidThread.runLoop {
                IOHIDManagerUnscheduleFromRunLoop(managerRef, runLoop, CFRunLoopMode.defaultMode.rawValue)
            }
            self.thread = nil
        }
        
        IOHIDManagerClose(managerRef, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        
        state.update { $0.isConnected = false }
        AppLogger.hid.info("HIDGamepadManager stopped.")
    }
    
    /// Forces a hot-reload of the active device layout from disk.
    @MainActor
    public func reloadActiveLayout() {
        guard let activeInfo = activeDevice else { return }
        
        deviceLock.lock()
        _activeLayout = LayoutManager.shared.loadLayout(for: activeInfo)
        deviceLock.unlock()
        
        AppLogger.hid.info("Reloaded active controller layout for: \(activeInfo.name)")
    }
    
    private func deviceMatched(device: IOHIDDevice) {
        Task { @MainActor in
            self.handleDeviceMatched(device: device)
        }
    }
    
    private func deviceRemoved(device: IOHIDDevice) {
        Task { @MainActor in
            self.handleDeviceRemoved(device: device)
        }
    }
    
    @MainActor
    private func handleDeviceMatched(device: IOHIDDevice) {
        guard let vendorIDRef = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString),
              let productIDRef = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) else {
            return
        }
        
        guard let vendorIDNum = vendorIDRef as? NSNumber,
              let productIDNum = productIDRef as? NSNumber else {
            return
        }
        
        let vendorID = vendorIDNum.intValue
        let productID = productIDNum.intValue
        
        let userOverrides = GameMacViewModel.shared.captureNativeControllers ? Set([vendorID]) : Set<Int>()
        if DeviceBlacklist.shouldSkip(vid: vendorID, userOverrides: userOverrides) {
            return
        }
        
        let name = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? "Unknown Controller"
        let info = DeviceInfo(name: name, vendorID: vendorID, productID: productID)
        
        self.hidDevices[device] = info
        notifyDevicesChanged()
        
        if activeDevice == nil {
            promoteHIDDevice(device)
        }
    }
    
    @MainActor
    private func handleDeviceRemoved(device: IOHIDDevice) {
        guard let info = hidDevices[device] else { return }
        
        self.hidDevices[device] = nil
        notifyDevicesChanged()
        
        if case .hid(let activeDev) = _activeDeviceRef, activeDev == device {
            onDeviceRemoved?()
            
            deviceLock.lock()
            _activeDeviceRef = .none
            _activeLayout = nil
            deviceLock.unlock()
            
            state.update { $0.isConnected = false }
            onActiveDeviceChanged?(nil)
            
            autoPromoteNext()
        }
    }
    
    @MainActor
    private func rawDeviceMatched(_ info: DeviceInfo) {
        self.rawDevices[info.layoutKey] = info
        notifyDevicesChanged()
        
        if activeDevice == nil {
            promoteRawDevice(info.layoutKey)
        }
    }
    
    @MainActor
    private func rawDeviceRemoved(_ info: DeviceInfo) {
        self.rawDevices[info.layoutKey] = nil
        notifyDevicesChanged()
        
        if case .raw(let activeKey) = _activeDeviceRef, activeKey == info.layoutKey {
            deviceLock.lock()
            _activeDeviceRef = .none
            _activeLayout = nil
            deviceLock.unlock()
            
            state.update { $0.isConnected = false }
            onActiveDeviceChanged?(nil)
            
            autoPromoteNext()
        }
    }
    
    @MainActor
    private func promoteHIDDevice(_ device: IOHIDDevice) {
        guard let info = hidDevices[device] else { return }
        
        deviceLock.lock()
        _activeDeviceRef = .hid(device)
        _activeLayout = LayoutManager.shared.loadLayout(for: info)
        deviceLock.unlock()
        
        state.update { $0.isConnected = true }
        onActiveDeviceChanged?(info)
        AppLogger.hid.info("Promoted active standard gamepad: \(info.name)")
    }
    
    @MainActor
    private func promoteRawDevice(_ key: String) {
        guard let info = rawDevices[key] else { return }
        
        deviceLock.lock()
        _activeDeviceRef = .raw(key)
        _activeLayout = LayoutManager.shared.loadLayout(for: info)
        deviceLock.unlock()
        
        // RawUSBGamepadManager updates state.isConnected and parses GIP inputs asynchronously.
        onActiveDeviceChanged?(info)
        AppLogger.hid.info("Promoted active Raw USB gamepad: \(info.name)")
    }
    
    @MainActor
    private func autoPromoteNext() {
        if let nextHID = hidDevices.keys.first {
            promoteHIDDevice(nextHID)
        } else if let nextRaw = rawDevices.keys.first {
            promoteRawDevice(nextRaw)
        }
    }
    
    @MainActor
    private func notifyDevicesChanged() {
        let allDevices = Array(hidDevices.values) + Array(rawDevices.values)
        onConnectedDevicesChanged?(allDevices)
    }
    
    @MainActor
    public func selectActiveDevice(_ device: DeviceInfo) {
        if let match = hidDevices.first(where: { $0.value.id == device.id }) {
            promoteHIDDevice(match.key)
        } else if let match = rawDevices.first(where: { $0.value.id == device.id }) {
            promoteRawDevice(match.key)
        }
    }
    
    private func inputValueReceived(value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        
        deviceLock.lock()
        var isCurrentActive = false
        if case let .hid(activeDev) = _activeDeviceRef, device == activeDev {
            isCurrentActive = true
        }
        let layout = _activeLayout
        deviceLock.unlock()
        
        guard isCurrentActive, let activeLayout = layout else { return }
        
        state.update { stateStruct in
            HIDInputParser.parse(valueRef: value, layout: activeLayout, into: &stateStruct)
        }
    }
}

@available(macOS 13.0, *)
private final class HIDThread: Thread {
    private let manager: IOHIDManager
    var runLoop: CFRunLoop?
    private let semaphore = DispatchSemaphore(value: 0)
    
    init(manager: IOHIDManager) {
        self.manager = manager
        super.init()
        self.name = "com.gamemac.HIDThread"
    }
    
    override func main() {
        guard let currentRunLoop = CFRunLoopGetCurrent() else {
            semaphore.signal()
            return
        }
        self.runLoop = currentRunLoop
        
        IOHIDManagerScheduleWithRunLoop(manager, currentRunLoop, CFRunLoopMode.defaultMode.rawValue)
        semaphore.signal()
        CFRunLoopRun()
    }
    
    func waitTillReady() {
        semaphore.wait()
    }
    
    func stopThread() {
        if let runLoop = runLoop {
            CFRunLoopStop(runLoop)
        }
    }
}
