import SwiftUI
import Combine

@MainActor
@available(macOS 13.0, *)
public final class GamepadDriverService: ObservableObject {
    public static let shared = GamepadDriverService()
    
    // Core engines
    public let atomicState = AtomicGamepadState()
    private var hidManager: HIDGamepadManager?
    private var inputMapper: InputMapper?
    private let stateTracker = StateTracker.shared
    private let mouseEngine = MouseVelocityEngine()
    
    // Driver-specific states
    @Published public var isDriverRunning = false
    @Published public var connectedDevices: [DeviceInfo] = []
    @Published public var activeDevice: DeviceInfo? = nil
    @Published public var activeControllerLayout: ControllerLayout? = nil
    @Published public var lastHardwareBindingMessage: String? = nil
    
    // Gamepad button binding state (contains the virtual element id, e.g. "buttonX")
    @Published public var bindingGamepadElementId: String? = nil {
        didSet {
            HIDInputParser.bindingEnabled = bindingGamepadElementId != nil
            if bindingGamepadElementId == nil {
                HIDInputParser.resetBindingState()
            }
        }
    }
    
    private var driverTimer: Timer?
    
    private init() {
        // Initialize mapper with a default profile (will be updated by the ViewModel when selected)
        self.inputMapper = InputMapper(
            atomicState: atomicState,
            stateTracker: stateTracker,
            mouseEngine: mouseEngine,
            profile: DefaultProfiles.fpsShooter // placeholder, will be set on launch
        )
        
        // Configure HID Manager with disconnection callback
        let manager = HIDGamepadManager(state: atomicState) {
            Task { @MainActor in
                StateTracker.shared.flush()
            }
        }
        self.hidManager = manager
        
        manager.onConnectedDevicesChanged = { [weak self] devices in
            Task { @MainActor in
                self?.connectedDevices = devices
            }
        }
        manager.onActiveDeviceChanged = { [weak self] device in
            Task { @MainActor in
                self?.activeDevice = device
                self?.activeControllerLayout = manager.activeLayout
            }
        }
        
        // HID hardware button binding (usage page + usage → composite layout key)
        manager.onHIDButtonPressed = { [weak self] page, usage in
            Task { @MainActor in
                guard let self = self,
                      let elementId = self.bindingGamepadElementId,
                      let device = self.activeDevice else { return }
                
                self.bindingGamepadElementId = nil
                
                var activeLayout = LayoutManager.shared.loadLayout(for: device)
                let compositeKey = HIDInputParser.elementKey(page: page, usage: usage)
                
                if (elementId == "leftTriggerButton" || elementId == "rightTriggerButton") && page != 0x09 {
                    LayoutManager.shared.applyAxisBinding(
                        layout: &activeLayout,
                        page: page,
                        usage: usage,
                        elementId: elementId
                    )
                } else {
                    LayoutManager.shared.applyButtonBinding(
                        layout: &activeLayout,
                        page: page,
                        usage: usage,
                        elementId: elementId
                    )
                }
                
                LayoutManager.shared.saveLayout(activeLayout)
                manager.activeLayout = activeLayout
                self.activeControllerLayout = activeLayout
                
                let keyLabel = HIDInputParser.formatElementKey(compositeKey)
                let message = "Bound: page 0x\(String(format: "%02X", page)) usage \(usage) (\(keyLabel)) → \(elementId) [layout: \(activeLayout.layoutKey)]"
                self.lastHardwareBindingMessage = message
                AppLogger.hid.info("[HID-BIND] \(message)")
                print("[HID-BIND] \(message)")
            }
        }
        
        // HID hardware axis binding (analog trigger page + usage → axisMap)
        manager.onHIDAxisPressed = { [weak self] page, usage in
            Task { @MainActor in
                guard let self = self,
                      let elementId = self.bindingGamepadElementId,
                      let device = self.activeDevice else { return }
                
                guard elementId == "leftTriggerButton" || elementId == "rightTriggerButton" else { return }
                
                self.bindingGamepadElementId = nil
                
                var activeLayout = LayoutManager.shared.loadLayout(for: device)
                let compositeKey = HIDInputParser.elementKey(page: page, usage: usage)
                
                LayoutManager.shared.applyAxisBinding(
                    layout: &activeLayout,
                    page: page,
                    usage: usage,
                    elementId: elementId
                )
                
                LayoutManager.shared.saveLayout(activeLayout)
                manager.activeLayout = activeLayout
                self.activeControllerLayout = activeLayout
                
                let keyLabel = HIDInputParser.formatElementKey(compositeKey)
                let message = "Bound: axis page 0x\(String(format: "%02X", page)) usage \(usage) (\(keyLabel)) → \(elementId) [layout: \(activeLayout.layoutKey)]"
                self.lastHardwareBindingMessage = message
                AppLogger.hid.info("[HID-BIND] \(message)")
                print("[HID-BIND] \(message)")
            }
        }
        
        // GIP hardware button binding (bitmask layout key, raw USB path)
        manager.onGamepadButtonPressed = { [weak self] bitmask in
            Task { @MainActor in
                guard let self = self,
                      let elementId = self.bindingGamepadElementId,
                      let device = self.activeDevice else { return }
                
                self.bindingGamepadElementId = nil
                
                var activeLayout = LayoutManager.shared.loadLayout(for: device)
                
                if let oldKey = activeLayout.buttonMap.first(where: { $0.value == elementId })?.key {
                    activeLayout.buttonMap.removeValue(forKey: oldKey)
                }
                
                activeLayout.buttonMap[Int(bitmask)] = elementId
                
                LayoutManager.shared.saveLayout(activeLayout)
                manager.activeLayout = activeLayout
                self.activeControllerLayout = activeLayout
                
                self.lastHardwareBindingMessage = "Bound: GIP bitmask \(bitmask) → \(elementId) [layout: \(activeLayout.layoutKey)]"
            }
        }
    }
    
    public func updateProfile(_ profile: MappingProfile) {
        inputMapper?.profile = profile
    }
    
    public func selectActiveDevice(_ device: DeviceInfo) {
        hidManager?.selectActiveDevice(device)
    }
    
    public func reloadActiveLayout() {
        hidManager?.reloadActiveLayout()
        if let active = activeDevice {
            activeControllerLayout = LayoutManager.shared.loadLayout(for: active)
        }
    }
    
    public func startDriver(isFpsMode: Bool) {
        guard !isDriverRunning else { return }
        
        hidManager?.start()
        mouseEngine.start()
        mouseEngine.mode = isFpsMode ? .fps : .desktop
        
        // Polling loop for mapping inputs (120Hz)
        driverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.inputMapper?.processCurrentState()
            }
        }
        
        isDriverRunning = true
        AppLogger.ui.info("GameMac mapper driver successfully started.")
    }
    
    public func stopDriver() {
        guard isDriverRunning else { return }
        
        driverTimer?.invalidate()
        driverTimer = nil
        
        hidManager?.stop()
        mouseEngine.stop()
        stateTracker.flush()
        
        isDriverRunning = false
        AppLogger.ui.info("GameMac mapper driver stopped.")
    }
    
    public func restartDriver(isFpsMode: Bool) {
        stopDriver()
        startDriver(isFpsMode: isFpsMode)
    }
}
