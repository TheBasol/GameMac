import SwiftUI
import Combine
import AppKit

@available(macOS 13.0, *)
public enum StickSide: String, CaseIterable, Identifiable {
    case left = "Left Stick"
    case right = "Right Stick"

    public var id: String { rawValue }

    var directionalKeys: (up: String, down: String, left: String, right: String) {
        switch self {
        case .left:
            return ("leftStickUp", "leftStickDown", "leftStickLeft", "leftStickRight")
        case .right:
            return ("rightStickUp", "rightStickDown", "rightStickLeft", "rightStickRight")
        }
    }

    var allDirectionalIds: [String] {
        let keys = directionalKeys
        return [keys.up, keys.down, keys.left, keys.right]
    }
}

@MainActor
@available(macOS 13.0, *)
public final class GameMacViewModel: ObservableObject {
    public static let shared = GameMacViewModel()

    private enum DefaultsKey {
        static let lastSelectedProfileName = "GameMac.lastSelectedProfileName"
        static let captureNativeControllers = "GameMac.captureNativeControllers"
    }

    // UI-facing states throttled to 60Hz
    @Published public var gamepadState = GamepadState()
    @Published public var isDriverRunning = false
    @Published public var hasAccessibilityPermission = false
    @Published public var hasInputMonitoringPermission = false
    @Published public var testInjectionStatus: String = "Not Tested"
    @Published public var testInjectionSucceeded: Bool? = nil
    @Published public var activeProfile: MappingProfile
    @Published public var profiles: [MappingProfile] = []

    // UI selection & key-capture coordination across visualizer and inspector
    @Published public var selectedControlId: String? = nil
    @Published public var showingNewProfileSheet: Bool = false
    @Published public var showingHardwareSetupSheet: Bool = false

    // Hardware layout binding state (physical gamepad input -> semantic element id)
    @Published public var bindingGamepadElementId: String? = nil {
        didSet {
            GamepadDriverService.shared.bindingGamepadElementId = bindingGamepadElementId
        }
    }
    @Published public var activeControllerLayout: ControllerLayout?
    @Published public var lastHardwareBindingMessage: String? = nil
    @Published public var liveRawAxisValues: [Int: Int] = [:]

    // Connected devices & Native controller capturing
    @Published public var connectedDevices: [DeviceInfo] = []
    @Published public var activeDevice: DeviceInfo?
    @Published public var captureNativeControllers: Bool = false {
        didSet {
            UserDefaults.standard.set(captureNativeControllers, forKey: DefaultsKey.captureNativeControllers)
            GamepadDriverService.shared.captureNativeControllers = captureNativeControllers
            if hasInitialized {
                restartDriver()
            }
        }
    }

    // Settings mirroring the active profile
    @Published public var deadZone: Double = 0.15
    @Published public var mouseSensitivity: Double = 1.5
    @Published public var mouseExponent: Double = 1.2
    @Published public var isFpsMode: Bool = false
    @Published public var leftStickMode: StickInputMode = .keyboard
    @Published public var rightStickMode: StickInputMode = .mouse

    public var hasAllPermissions: Bool {
        hasAccessibilityPermission && hasInputMonitoringPermission
    }

    private var hasInitialized = false
    private var isRawTelemetryActive = false
    private var uiUpdateTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let savedCapture = UserDefaults.standard.bool(forKey: DefaultsKey.captureNativeControllers)
        self.captureNativeControllers = savedCapture
        GamepadDriverService.shared.captureNativeControllers = savedCapture

        // Initialize/load profiles
        var existingProfiles = ProfileManager.shared.listProfiles()
        if existingProfiles.isEmpty {
            for profile in DefaultProfiles.all {
                try? ProfileManager.shared.saveProfile(profile)
            }
            existingProfiles = ProfileManager.shared.listProfiles()
        }

        let lastProfileName = UserDefaults.standard.string(forKey: DefaultsKey.lastSelectedProfileName)
        let initialProfile = existingProfiles.first(where: { $0.profileName == lastProfileName })
            ?? existingProfiles.first(where: { $0.profileName == DefaultProfiles.fpsShooter.profileName })
            ?? existingProfiles.first
            ?? DefaultProfiles.fpsShooter

        self.activeProfile = initialProfile
        self.profiles = existingProfiles

        // Sync published tuning values with initial profile
        self.deadZone = initialProfile.deadZone
        self.mouseSensitivity = initialProfile.mouseSensitivity
        self.mouseExponent = initialProfile.mouseExponent
        self.isFpsMode = initialProfile.isFpsMode
        self.leftStickMode = initialProfile.leftStickMode
        self.rightStickMode = initialProfile.rightStickMode

        GamepadDriverService.shared.updateProfile(initialProfile)

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

        // Automatically re-check macOS permissions when user returns from System Settings
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkPermissions()
            }
            .store(in: &cancellables)

        // Throttle UI updates to 60Hz to prevent unnecessary SwiftUI redraws
        self.uiUpdateTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateUIState()
            }

        hasInitialized = true
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
        testInjectionSucceeded = success
        if success {
            testInjectionStatus = "Verified — Event injection is active"
        } else {
            testInjectionStatus = "Blocked — Grant Accessibility permission in System Settings"
        }
    }

    public func startDriver() {
        GamepadDriverService.shared.startDriver(isFpsMode: isFpsMode)
    }

    public func stopDriver() {
        GamepadDriverService.shared.stopDriver()
    }

    public func toggleDriver() {
        if isDriverRunning {
            stopDriver()
        } else {
            startDriver()
        }
    }

    public func restartDriver() {
        GamepadDriverService.shared.restartDriver(isFpsMode: isFpsMode)
    }

    public func setMouseMode(isFpsMode: Bool) {
        guard self.isFpsMode != isFpsMode else { return }
        self.isFpsMode = isFpsMode
        GamepadDriverService.shared.setMouseMode(isFpsMode: isFpsMode)
        saveCurrentProfile()
    }

    public func setRawTelemetryEnabled(_ enabled: Bool) {
        isRawTelemetryActive = enabled
        GamepadDriverService.shared.setRawTelemetryEnabled(enabled)
        if !enabled {
            liveRawAxisValues = [:]
        }
    }

    private func updateUIState() {
        let current = GamepadDriverService.shared.atomicState.read()
        if self.gamepadState != current {
            self.gamepadState = current
        }
        if isRawTelemetryActive {
            let snapshot = GamepadDriverService.shared.readRawAxisSnapshot()
            if self.liveRawAxisValues != snapshot {
                self.liveRawAxisValues = snapshot
            }
        }
    }

    public func selectActiveDevice(_ device: DeviceInfo) {
        GamepadDriverService.shared.selectActiveDevice(device)
    }

    public func resetActiveHardwareLayout() {
        GamepadDriverService.shared.resetActiveLayout()
    }

    // MARK: - Profile Management

    public func selectProfile(_ profile: MappingProfile) {
        self.activeProfile = profile
        self.deadZone = profile.deadZone
        self.mouseSensitivity = profile.mouseSensitivity
        self.mouseExponent = profile.mouseExponent
        self.isFpsMode = profile.isFpsMode
        self.leftStickMode = profile.leftStickMode
        self.rightStickMode = profile.rightStickMode

        UserDefaults.standard.set(profile.profileName, forKey: DefaultsKey.lastSelectedProfileName)
        GamepadDriverService.shared.updateProfile(profile)
        GamepadDriverService.shared.setMouseMode(isFpsMode: profile.isFpsMode)
        StateTracker.shared.flush()

        AppLogger.ui.info("Selected profile: \(profile.profileName)")
    }

    public func saveCurrentProfile() {
        var updated = activeProfile
        updated.deadZone = deadZone
        updated.mouseSensitivity = mouseSensitivity
        updated.mouseExponent = mouseExponent
        updated.isFpsMode = isFpsMode
        updated.leftStickMode = leftStickMode
        updated.rightStickMode = rightStickMode
        activeProfile = updated
        GamepadDriverService.shared.updateProfile(updated)

        do {
            try ProfileManager.shared.saveProfile(updated)
            profiles = ProfileManager.shared.listProfiles()
        } catch {
            AppLogger.ui.error("Failed to save profile: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func createProfile(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !ProfileManager.shared.profileExists(named: trimmed) else {
            return false
        }
        let newProfile = MappingProfile(
            profileName: trimmed,
            buttonMapping: [:],
            deadZone: 0.15,
            mouseSensitivity: 1.5,
            mouseExponent: 1.2,
            isFpsMode: false,
            leftStickMode: .disabled,
            rightStickMode: .disabled
        )
        do {
            try ProfileManager.shared.saveProfile(newProfile)
            profiles = ProfileManager.shared.listProfiles()
            selectProfile(newProfile)
            return true
        } catch {
            AppLogger.ui.error("Failed to create profile: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    public func renameProfile(_ profile: MappingProfile, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.caseInsensitiveCompare(profile.profileName) != .orderedSame,
           ProfileManager.shared.profileExists(named: trimmed) {
            return false
        }
        do {
            let renamed = try ProfileManager.shared.renameProfile(profile, to: trimmed)
            profiles = ProfileManager.shared.listProfiles()
            if activeProfile.profileName == profile.profileName {
                selectProfile(renamed)
            }
            return true
        } catch {
            AppLogger.ui.error("Failed to rename profile: \(error.localizedDescription)")
            return false
        }
    }

    public func duplicateProfile(_ profile: MappingProfile) {
        var copy = profile
        copy.profileName = ProfileManager.shared.uniqueProfileName(base: profile.profileName)
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
            if activeProfile.profileName == profile.profileName, let first = profiles.first {
                selectProfile(first)
            }
        } catch {
            AppLogger.ui.error("Failed to delete profile: \(error.localizedDescription)")
        }
    }

    public func restoreDefaultProfiles() {
        do {
            try ProfileManager.shared.restoreDefaultProfiles()
            profiles = ProfileManager.shared.listProfiles()
            if let currentMatch = profiles.first(where: { $0.profileName == activeProfile.profileName }) {
                selectProfile(currentMatch)
            } else if let first = profiles.first {
                selectProfile(first)
            }
        } catch {
            AppLogger.ui.error("Failed to restore default profiles: \(error.localizedDescription)")
        }
    }

    public func updateMapping(for elementKey: String, to keyCode: UInt16?) {
        var updated = activeProfile
        if let code = keyCode {
            updated.buttonMapping[elementKey] = code
        } else {
            updated.buttonMapping.removeValue(forKey: elementKey)
        }
        StateTracker.shared.flush()
        activeProfile = updated
        GamepadDriverService.shared.updateProfile(updated)

        try? ProfileManager.shared.saveProfile(updated)
        profiles = ProfileManager.shared.listProfiles()
    }

    public func setStickMode(stick: StickSide, mode: StickInputMode) {
        var updated = activeProfile
        let keys = stick.directionalKeys

        switch stick {
        case .left:
            updated.leftStickMode = mode
            self.leftStickMode = mode
        case .right:
            updated.rightStickMode = mode
            self.rightStickMode = mode
        }

        if mode == .keyboard {
            // Preload sensible defaults when no directional keys are currently mapped
            let hasAny = stick.allDirectionalIds.contains { updated.buttonMapping[$0] != nil }
            if !hasAny {
                switch stick {
                case .left:
                    updated.buttonMapping[keys.up] = KeyCodes.w
                    updated.buttonMapping[keys.down] = KeyCodes.s
                    updated.buttonMapping[keys.left] = KeyCodes.a
                    updated.buttonMapping[keys.right] = KeyCodes.d
                case .right:
                    updated.buttonMapping[keys.up] = KeyCodes.upArrow
                    updated.buttonMapping[keys.down] = KeyCodes.downArrow
                    updated.buttonMapping[keys.left] = KeyCodes.leftArrow
                    updated.buttonMapping[keys.right] = KeyCodes.rightArrow
                }
            }
        } else {
            for id in stick.allDirectionalIds {
                updated.buttonMapping.removeValue(forKey: id)
            }
        }

        StateTracker.shared.flush()
        activeProfile = updated
        GamepadDriverService.shared.updateProfile(updated)
        try? ProfileManager.shared.saveProfile(updated)
        profiles = ProfileManager.shared.listProfiles()
    }

    public func reloadProfiles() {
        profiles = ProfileManager.shared.listProfiles()
        if !profiles.contains(where: { $0.profileName == activeProfile.profileName }), let first = profiles.first {
            selectProfile(first)
        }
    }

    public func revealProfilesFolder() {
        ProfileManager.shared.createDirectoryIfNeeded()
        NSWorkspace.shared.activateFileViewerSelecting([ProfileManager.shared.profilesDirectory])
    }
}
