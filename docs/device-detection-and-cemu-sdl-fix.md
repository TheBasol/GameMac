# Controller Auto-Detection & SDL2 (SDLController) Compatibility

Documentation of issues identified and resolved in September 2026 regarding GameSir-K1 wake-up detection in GameMac and controller recognition across the macOS SDL2 (`SDL_GameController`) ecosystem, with Cemu as the primary verified case study.

---

## 1. GameSir-K1 Not Auto-Detected on Launch / Reconnection

### Symptoms
* After unplugging/replugging the controller or rebooting macOS, GameMac would not detect the GameSir-K1 controller ("otra vez no lo detectó").
* Neither `RawUSBGamepadManager` nor `IOHIDManager` reported any connected devices in the logs.
* The controller only became active after manual low-level diagnostic intervention via terminal.

### Root Cause
1. **Controller Hardware Lifecycle**:
   * The GameSir-K1 (and similar wired Xbox GIP devices) connects in an unconfigured, raw USB mode:
     * Vendor ID: `0x3537` (Guangzhou Chicken Run Network Technology Co., Ltd.)
     * Initial Product ID: `0x1012`
     * Class: `255` (Vendor Specific)
   * In this state, macOS does not expose any standard HID gamepad interface. The controller requires a host application to open the device and issue `SetConfiguration(1)` to transition to configured mode (Interface #3, PID `0x1058`, Class 3 HID Gamepad).

2. **IOKit Matching Bug in `RawUSBGamepadManager`**:
   * The matching dictionary was previously constructed as:
     ```swift
     let matchedDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
     matchedDict[kUSBVendorID] = 0x3537 // ❌ Ignored by IOKit
     ```
   * In macOS IOKit, arbitrary property matching on an `IOService` dictionary must be nested under the `"IOPropertyMatch"` key. Passing `idVendor` at the root dictionary level caused `IOServiceAddMatchingNotification` to silently match **0 devices**.
   * Consequently, `handleDevicesMatched` was never triggered, `SetConfiguration(1)` was never sent, and the controller remained asleep.

### Fix
In [`GameMac/HID/RawUSBGamepadManager.swift`](../GameMac/HID/RawUSBGamepadManager.swift#L106-L114), wrap the vendor ID filter inside an `IOPropertyMatch` dictionary for both `matchedDict` and `removedDict`:

```swift
// Build Matching Dictionaries for GameSir controllers (VID: 0x3537)
let matchedDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
let matchedProp = NSMutableDictionary()
matchedProp["idVendor"] = 0x3537
matchedDict["IOPropertyMatch"] = matchedProp

let removedDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
let removedProp = NSMutableDictionary()
removedProp["idVendor"] = 0x3537
removedDict["IOPropertyMatch"] = removedProp
```

**Result**: `IOServiceAddMatchingNotification` triggers immediately upon device attachment or app launch. GameMac sets configuration 1, waking the controller and exposing the standard HID gamepad interface (`3537_1058`) to `IOHIDManager`.

---

## 2. Controller Detection in Generic HID vs. SDL2 (SDL_GameController)

### Symptoms
* Once awakened by GameMac, emulators with direct HID backends (such as **Dolphin**) recognized the GameSir-K1 immediately.
* However, applications relying on **SDL2's `SDLController` subsystem** (specifically **Cemu** under *Options → Input settings → SDLController*) showed an empty controller list and failed to detect the device.

### Architectural Difference Between macOS Input Backends
macOS games and emulators generally query controller input through three distinct pipelines:

| Backend | Mechanism | Compatibility with GameSir-K1 |
|---|---|---|
| **macOS Native (`GCController`)** | Apple GameController framework | **Unsupported**. Apple only whitelist-supports MFi, DualSense, DualShock 4, Nintendo Switch, and Xbox Wireless (Bluetooth) controllers. |
| **Generic HID (`IOHIDManager`)** | Direct OS-level USB/HID reports | **Supported directly** (used by Dolphin, GameMac). Once GameMac triggers `SetConfiguration(1)`, the OS publishes a standard HID Gamepad (`Usage Page 1, Usage 5`), making it instantly readable. |
| **SDL2 (`SDL_GameController`)** | Cross-platform abstraction layer | **Requires Database Entry**. Standard backend for Cemu, Ryujinx, RPCS3, RetroArch, and many indie game engines. |

### The SDL2 `gamecontrollerdb` Requirement
1. Rather than raw joystick access (`SDL_Joystick`), modern emulators rely on `SDL_GameController` to obtain normalized Xbox/PlayStation layout mappings (buttons A/B/X/Y, axes, triggers).
2. SDL2 enforces a strict validation check:
   ```c
   int isGameController = SDL_IsGameController(device_index);
   ```
   If the device's hardware GUID is not present in SDL2's embedded or external `gamecontrollerdb`, `SDL_IsGameController` returns `0` (false).
3. On macOS, the GameSir-K1 produces the GUID:
   ```
   0300a05e373500005810000051010000
   ```
4. Because this GUID was absent from SDL2's built-in database, SDL2 classified it as an unmapped generic joystick. **Cemu** (and other SDL2-dependent apps) filters out any device that fails `SDL_IsGameController`, resulting in an empty controller selection menu.

### Resolution

#### 1. Official SDL2 Mapping Definition
Constructed the complete SDL2 mapping string for macOS:
```
0300a05e373500005810000051010000,GameSir-K1 Controller for Xbox,a:b0,b:b1,x:b3,y:b4,back:b10,start:b11,guide:b12,leftstick:b8,rightstick:b9,leftshoulder:b6,rightshoulder:b7,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,platform:Mac OS X,
```

#### 2. Runtime In-App Injection via GameMac (`AppDelegate.swift`)
To ensure clean integration without polluting the user's permanent macOS startup items (`~/Library/LaunchAgents` or login items), GameMac dynamically injects the mapping into the session environment upon launch in [`GameMac/App/AppDelegate.swift`](../GameMac/App/AppDelegate.swift):

```swift
public func applicationDidFinishLaunching(_ notification: Notification) {
    AppLogger.default.info("GameMac application started.")
    setupSDLEnvironment()
}

/// Exports the GameSir-K1 mapping for SDL2-based applications (such as Cemu) dynamically during runtime.
private func setupSDLEnvironment() {
    let mapping = "0300a05e373500005810000051010000,GameSir-K1 Controller for Xbox,a:b0,b:b1,x:b3,y:b4,back:b10,start:b11,guide:b12,leftstick:b8,rightstick:b9,leftshoulder:b6,rightshoulder:b7,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,platform:Mac OS X,"
    
    // 1. Process level
    setenv("SDL_GAMECONTROLLERCONFIG", mapping, 1)
    
    // 2. User graphical session level so external apps (Cemu, etc.) inherit it
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
```

#### 3. Standalone Database Fallback
For environments where environment variable propagation might be isolated, a standard `gamecontrollerdb.txt` file was also placed in Cemu's application support directory:
* `~/Library/Application Support/Cemu/gamecontrollerdb.txt`
* `/Volumes/Satochi SSD/Applications-SSD/Cemu.app/Contents/Resources/gamecontrollerdb.txt`

### Verification
* Running `SDL_IsGameController(0)` on the device now returns `1` (true).
* In **Cemu**, under *Options → Input settings → SDLController*, `GameSir-K1 Controller for Xbox` is detected and fully configurable.
* The solution remains active for all SDL2-based applications as long as GameMac is running during the session, without leaving background daemons or login items behind.
