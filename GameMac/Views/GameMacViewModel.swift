import SwiftUI
import Combine

@MainActor
@available(macOS 13.0, *)
public final class GameMacViewModel: ObservableObject {
    public static let shared = GameMacViewModel()
    
    // UI-facing states throttled to 60Hz
    @Published public var gamepadState = GamepadState()
    @Published public var isDriverRunning = false
    @Published public var hasAccessibilityPermission = false
    @Published public var hasInputMonitoringPermission = false
    @Published public var testInjectionStatus: String = "Not Tested"
    @Published public var activeProfile: MappingProfile
    @Published public var profiles: [MappingProfile] = []
    
    // Gamepad button binding state (contains the virtual element id, e.g. "buttonX")
    @Published public var bindingGamepadElementId: String? = nil {
        didSet {
            GamepadDriverService.shared.bindingGamepadElementId = bindingGamepadElementId
        }
    }
    @Published public var activeControllerLayout: ControllerLayout?
    @Published public var lastHardwareBindingMessage: String? = nil
    
    // Connected devices & Native controller capturing
    @Published public var connectedDevices: [DeviceInfo] = []
    @Published public var activeDevice: DeviceInfo?
    @Published public var captureNativeControllers: Bool = false {
        didSet {
            restartDriver()
        }
    }
    
    // Settings mirroring the active profile
    @Published public var deadZone: Double = 0.15
    @Published public var mouseSensitivity: Double = 1.5
    @Published public var mouseExponent: Double = 1.2
    @Published public var isFpsMode: Bool = false
    
    private var uiUpdateTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initialize/load profiles
        let existingProfiles = ProfileManager.shared.listProfiles()
        if let first = existingProfiles.first {
            self.activeProfile = first
        } else {
            let fps = DefaultProfiles.fpsShooter
            let plat = DefaultProfiles.platformer
            try? ProfileManager.shared.saveProfile(fps)
            try? ProfileManager.shared.saveProfile(plat)
            self.activeProfile = fps
        }
        
        self.profiles = ProfileManager.shared.listProfiles()
        
        // Sync setting sliders
        self.deadZone = activeProfile.deadZone
        self.mouseSensitivity = activeProfile.mouseSensitivity
        self.mouseExponent = activeProfile.mouseExponent
        
        // Propagate initial profile to driver service
        GamepadDriverService.shared.updateProfile(activeProfile)
        
        // Bind to GamepadDriverService publishers
        let service = GamepadDriverService.shared
        
        service.$isDriverRunning
            .assign(to: \.isDriverRunning, on: self)
            .store(in: &cancellables)
            
        service.$connectedDevices
            .assign(to: \.connectedDevices, on: self)
            .store(in: &cancellables)
            
        service.$activeDevice
            .assign(to: \.activeDevice, on: self)
            .store(in: &cancellables)
            
        service.$activeControllerLayout
            .assign(to: \.activeControllerLayout, on: self)
            .store(in: &cancellables)
            
        service.$lastHardwareBindingMessage
            .assign(to: \.lastHardwareBindingMessage, on: self)
            .store(in: &cancellables)
            
        service.$bindingGamepadElementId
            .sink { [weak self] val in
                if self?.bindingGamepadElementId != val {
                    self?.bindingGamepadElementId = val
                }
            }
            .store(in: &cancellables)
        
        // Throttle UI updates to 60Hz to prevent lag (Fix #1)
        self.uiUpdateTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateUIState()
            }
        
        checkPermissions()
        startDriver()
    }
    
    public func checkPermissions() {
        self.hasAccessibilityPermission = PermissionChecker.shared.checkAccessibility(prompt: false)
        self.hasInputMonitoringPermission = PermissionChecker.shared.checkInputMonitoring()
    }
    
    public func performTestInjection() {
        checkPermissions()
        let success = EventInjector.runDiagnostics()
        if success {
            testInjectionStatus = "Success"
        } else {
            testInjectionStatus = "Failed (Verify accessibility permissions)"
        }
    }
    
    public func startDriver() {
        GamepadDriverService.shared.startDriver(isFpsMode: isFpsMode)
    }
    
    public func stopDriver() {
        GamepadDriverService.shared.stopDriver()
    }
    
    public func restartDriver() {
        GamepadDriverService.shared.restartDriver(isFpsMode: isFpsMode)
    }
    
    private func updateUIState() {
        let current = GamepadDriverService.shared.atomicState.read()
        if self.gamepadState != current {
            self.gamepadState = current
        }
    }
    
    public func selectActiveDevice(_ device: DeviceInfo) {
        GamepadDriverService.shared.selectActiveDevice(device)
    }
    
    // Profile Management
    public func selectProfile(_ profile: MappingProfile) {
        self.activeProfile = profile
        self.deadZone = profile.deadZone
        self.mouseSensitivity = profile.mouseSensitivity
        self.mouseExponent = profile.mouseExponent
        
        GamepadDriverService.shared.updateProfile(profile)
        StateTracker.shared.flush()
        
        AppLogger.ui.info("Selected profile: \(profile.profileName)")
    }
    
    public func saveCurrentProfile() {
        var updated = activeProfile
        updated.deadZone = deadZone
        updated.mouseSensitivity = mouseSensitivity
        updated.mouseExponent = mouseExponent
        activeProfile = updated
        GamepadDriverService.shared.updateProfile(updated)
        
        do {
            try ProfileManager.shared.saveProfile(updated)
            profiles = ProfileManager.shared.listProfiles()
        } catch {
            AppLogger.ui.error("Failed to save profile: \(error.localizedDescription)")
        }
    }
    
    public func createProfile(name: String) {
        let newProfile = MappingProfile(
            profileName: name,
            buttonMapping: [:],
            deadZone: 0.15,
            mouseSensitivity: 1.5,
            mouseExponent: 1.2
        )
        do {
            try ProfileManager.shared.saveProfile(newProfile)
            profiles = ProfileManager.shared.listProfiles()
            selectProfile(newProfile)
        } catch {
            AppLogger.ui.error("Failed to create profile: \(error.localizedDescription)")
        }
    }
    
    public func duplicateProfile(_ profile: MappingProfile) {
        var copy = profile
        copy.profileName = "\(profile.profileName) Copy"
        do {
            try ProfileManager.shared.saveProfile(copy)
            profiles = ProfileManager.shared.listProfiles()
            selectProfile(copy)
        } catch {
            AppLogger.ui.error("Failed to duplicate profile: \(error.localizedDescription)")
        }
    }
    
    public func deleteProfile(_ profile: MappingProfile) {
        guard profiles.count > 1 else { return }
        do {
            try ProfileManager.shared.deleteProfile(named: profile.profileName)
            profiles = ProfileManager.shared.listProfiles()
            if let first = profiles.first {
                selectProfile(first)
            }
        } catch {
            AppLogger.ui.error("Failed to delete profile: \(error.localizedDescription)")
        }
    }
    
    public func updateMapping(for elementKey: String, to keyCode: UInt16?) {
        var updated = activeProfile
        if let code = keyCode {
            updated.buttonMapping[elementKey] = code
        } else {
            updated.buttonMapping.removeValue(forKey: elementKey)
        }
        activeProfile = updated
        GamepadDriverService.shared.updateProfile(updated)
        
        try? ProfileManager.shared.saveProfile(updated)
        profiles = ProfileManager.shared.listProfiles()
    }
}
