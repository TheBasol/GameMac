import Foundation

public final class LayoutManager {
    public static let shared = LayoutManager()

    private init() {}

    /// Standard generic Xbox controller layout fallback.
    public static var genericLayout: ControllerLayout {
        return ControllerLayout(
            layoutKey: "generic",
            deviceName: "Generic Xbox Controller",
            axisMap: [
                48: "leftStickX",
                49: "leftStickY",
                50: "rightStickX",
                53: "rightStickY",
                51: "leftTrigger",
                52: "rightTrigger"
            ],
            buttonMap: [
                1: "buttonA",
                2: "buttonB",
                3: "buttonX",
                4: "buttonY",
                5: "leftBumper",
                6: "rightBumper",
                7: "select",
                8: "start",
                9: "home",
                10: "menu"
            ]
        )
    }

    /// GameSir K1 analog trigger composite keys (page 0x02, usages 197/196).
    private static let gameSirK1LeftTriggerKey = 131269   // 0x000200C5
    private static let gameSirK1RightTriggerKey = 131268  // 0x000200C4

    /// Default fallback for 3537_1012 (GameSir Kaleid K1).
    public static var gameSirK1Layout: ControllerLayout {
        return ControllerLayout(
            layoutKey: "3537_1012",
            deviceName: "GameSir Kaleid K1",
            axisMap: [
                48: "leftStickX",
                49: "leftStickY",
                50: "rightStickX",
                53: "rightStickY",
                51: "leftTrigger",
                52: "rightTrigger",
                gameSirK1LeftTriggerKey: "leftTrigger",
                gameSirK1RightTriggerKey: "rightTrigger"
            ],
            buttonMap: [
                1: "buttonA",
                2: "buttonB",
                3: "buttonX",
                4: "buttonY",
                5: "leftBumper",
                6: "rightBumper",
                7: "select",
                8: "start",
                9: "leftTriggerButton",
                10: "rightTriggerButton",
                11: "home"
            ]
        )
    }

    /// Default fallback for 3537_1058 (GameSir-K1 Controller for Xbox).
    public static var gameSirK1XboxLayout: ControllerLayout {
        return ControllerLayout(
            layoutKey: "3537_1058",
            deviceName: "GameSir-K1 Controller for Xbox",
            axisMap: [
                48: "leftStickX",
                49: "leftStickY",
                50: "rightStickX",
                53: "rightStickY",
                51: "leftTrigger",
                52: "rightTrigger",
                gameSirK1LeftTriggerKey: "leftTrigger",
                gameSirK1RightTriggerKey: "rightTrigger"
            ],
            buttonMap: [
                1: "buttonA",
                2: "buttonB",
                3: "buttonX",
                4: "buttonY",
                5: "leftBumper",
                6: "rightBumper",
                7: "select",
                8: "start",
                9: "leftTriggerButton",
                10: "rightTriggerButton",
                11: "home"
            ]
        )
    }

    /// Applies a hardware axis binding for analog triggers, removing conflicting entries.
    public func applyAxisBinding(
        layout: inout ControllerLayout,
        page: UInt32,
        usage: UInt32,
        elementId: String
    ) {
        let axisName: String
        switch elementId {
        case "leftTriggerButton": axisName = "leftTrigger"
        case "rightTriggerButton": axisName = "rightTrigger"
        default: return
        }
        
        let compositeKey = HIDInputParser.elementKey(page: page, usage: usage)
        
        if let oldKey = layout.axisMap.first(where: { $0.value == axisName })?.key {
            layout.axisMap.removeValue(forKey: oldKey)
        }
        
        layout.axisMap[compositeKey] = axisName
        
        // Remove mistaken buttonMap binding for the same trigger element
        if let oldBtnKey = layout.buttonMap.first(where: { $0.value == elementId })?.key {
            layout.buttonMap.removeValue(forKey: oldBtnKey)
        }
        layout.buttonMap.removeValue(forKey: compositeKey)
    }

    /// Applies a hardware button binding, removing conflicting legacy and composite keys.
    public func applyButtonBinding(
        layout: inout ControllerLayout,
        page: UInt32,
        usage: UInt32,
        elementId: String
    ) {
        let compositeKey = HIDInputParser.elementKey(page: page, usage: usage)
        
        if let oldKey = layout.buttonMap.first(where: { $0.value == elementId })?.key {
            layout.buttonMap.removeValue(forKey: oldKey)
        }
        
        layout.buttonMap.removeValue(forKey: compositeKey)
        if page == 0x09 {
            layout.buttonMap.removeValue(forKey: Int(usage))
        }
        
        layout.buttonMap[compositeKey] = elementId
    }

    /// Loads a layout for the given layoutKey.
    /// It attempts to load from the following locations in order:
    /// 1. ~/Library/Application Support/GameMac/Layouts/<layoutKey>.json
    /// 2. Built-in files in the app bundle (Layouts/<layoutKey>.json or <layoutKey>.json)
    /// 3. Static/hardcoded fallback if the key matches a known layout
    /// 4. Fallback to the generic layout
    public func loadLayout(layoutKey: String) -> ControllerLayout {
        // 1. Try Application Support
        if let appSupportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            let userLayoutURL = appSupportURL
                .appendingPathComponent("GameMac", isDirectory: true)
                .appendingPathComponent("Layouts", isDirectory: true)
                .appendingPathComponent("\(layoutKey).json")
            
            if FileManager.default.fileExists(atPath: userLayoutURL.path),
               let data = try? Data(contentsOf: userLayoutURL),
               let layout = try? JSONDecoder().decode(ControllerLayout.self, from: data) {
                return layout
            }
        }

        // 2. Try App Bundle
        // Search first in a "Layouts" subdirectory, then in the resource root
        let bundles = [Bundle.main, Bundle(for: Self.self)]
        for bundle in bundles {
            if let bundleURL = bundle.url(forResource: layoutKey, withExtension: "json", subdirectory: "Layouts") ??
                                bundle.url(forResource: layoutKey, withExtension: "json") {
                if let data = try? Data(contentsOf: bundleURL),
                   let layout = try? JSONDecoder().decode(ControllerLayout.self, from: data) {
                    return layout
                }
            }
        }

        // 3. Static fallback
        if layoutKey == "3537_1012" {
            return Self.gameSirK1Layout
        } else if layoutKey == "3537_1058" {
            return Self.gameSirK1XboxLayout
        } else if layoutKey == "generic" {
            return Self.genericLayout
        }

        // 4. Default fallback
        return Self.genericLayout
    }

    /// Loads a layout using device info's layoutKey.
    public func loadLayout(for device: DeviceInfo) -> ControllerLayout {
        return loadLayout(layoutKey: device.layoutKey)
    }
    
    /// Saves a modified layout to the user's Application Support directory.
    public func saveLayout(_ layout: ControllerLayout) {
        guard let appSupportURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return }
        
        let layoutsDirectory = appSupportURL
            .appendingPathComponent("GameMac", isDirectory: true)
            .appendingPathComponent("Layouts", isDirectory: true)
            
        do {
            try FileManager.default.createDirectory(at: layoutsDirectory, withIntermediateDirectories: true)
            let fileURL = layoutsDirectory.appendingPathComponent("\(layout.layoutKey).json")
            
            let data = try JSONEncoder().encode(layout)
            try data.write(to: fileURL)
            AppLogger.hid.info("Successfully saved controller layout: \(layout.layoutKey)")
        } catch {
            AppLogger.hid.error("Failed to save controller layout: \(error.localizedDescription)")
        }
    }
}
