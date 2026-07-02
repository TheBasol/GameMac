# GameMac Controller Bridge

GameMac is a native macOS application (Apple Silicon and Intel processors, macOS 13.0+) specifically designed to resolve the recognition issue of the **GameSir Kaleid K1** controller (and similar generic USB HID controllers).

Since macOS does not natively recognize this controller as a compatible Game Controller (and Steam/games ignore it), GameMac acts as a high-performance, hardware-level bridge that reads raw HID data from the USB port and injects them as virtual keyboard and mouse events at the operating system level.

---

## Key Features

1. **Low-Level HID Reading:** Direct connection using `IOHIDManager` at 250Hz–1000Hz (full polling rate) running on a dedicated thread with its own run loop (`CFRunLoop`) to avoid interfering with the UI or game.
2. **High-Frequency Injection:** Injection engine running at **120Hz** with critical priority (`.userInteractive`) and zero leeway tolerance (`leeway: 0ns`), avoiding micro-stuttering (jitter) in aiming.
3. **App Nap Prevention:** Prevents macOS from degrading process priority when the app runs in the background using high-priority system activities.
4. **Mouse Velocity Engine:** Smooth mouse emulation with exponential acceleration curves and support for two modes:
 - **Desktop Mode:** Mapping to absolute cursor movement with screen boundaries (`NSScreen`).
 - **FPS Mode:** Mapping to pure relative deltas (`CGAssociateMouseAndMouseCursorPosition(false)`) and auto-centering the cursor before re-associating to avoid the "whiplash" effect.
5. **Smart State Tracker:** Active registration of pressed keys to prevent virtual keys from getting stuck (Ghost Inputs). Complete cleanup when disconnecting the controller, changing profiles, or closing the app.
6. **Premium User Interface:** Real-time visualization of the controller at 60Hz (saving main thread resources) and a responsive mapping editor.

---

## How to Build and Run

### Requirements
* Mac with Apple Silicon or Intel processor.
* macOS 13.0 (Ventura) or later.
* **Xcode** installed (you can download it for free from the Mac App Store).

### Step 1: Generate the Xcode Project
We have included a Python script that automatically generates the Xcode project structure:

```bash
# In the project root
python3 setup_project.py
```
*(Note: If you do not use the script, simply open Xcode, create a new SwiftUI application named `GameMac`, make sure to disable the **"App Sandbox"** option in the Signing & Capabilities tab, and drag the `GameMac` folder into the project).*

### Step 2: Compile in Xcode
1. Open `GameMac.xcodeproj`.
2. Select your Mac as the build target (top left corner).
3. Press **Cmd + R** or click the **Play** button to build and run.

---

## System Permissions (Very Important!)

To inject keyboard and mouse events into the system, macOS requires you to grant Accessibility permissions.

1. When opening the app for the first time, you will be prompted for **Accessibility** permission.
2. Go to `System Settings > Privacy & Security > Accessibility`.
3. Enable the checkbox for **GameMac**.

### Silent Revocation Bug (macOS Ventura, Sonoma, Sequoia and later)
macOS has a strict security policy: **if you rebuild the app or change the binary, permissions may silently stop working** because the binary's hash has changed, even though the switch still shows as "On" in System Settings.

**How to fix it:**
If you notice that the app detects your controller (the on-screen visualizer lights up) but games or the system do not respond to inputs:
1. Go to `System Settings > Privacy & Security > Accessibility`.
2. Select **GameMac** in the list.
3. Click the **Minus (−)** button at the bottom to remove the app completely from the list.
4. Re-open the app (or drag the compiled executable back into the list) to register it with its new security hash.

---

## Behavior on Unexpected Close (Crashes or SIGKILL)

GameMac implements an emergency cleanup routine (`flushAllKeys()`) that releases all virtual keys in the system when you disconnect the controller, change profiles, or close the app normally (`Cmd + Q`).

**If the app crashes or is forced to quit (e.g. SIGKILL from Terminal/Activity Monitor):**
The operating system might retain the last sent keyboard signal (for example, your character will keep walking forward infinitely on the `W` key).

* **Solution:** Simply **press the affected physical key once on your Mac's physical keyboard** (e.g., the `W` key). This will notify the macOS graphics server (`WindowServer`) that the key has been released and restore normal behavior.

---

## Anti-Cheat Compatibility

GameMac injects events using the standard Apple API (`CGEvent.post`).
* The vast majority of native Mac games, Steam games, and emulators (such as RPCS3, Ryujinx, Dolphin, OpenEmu) work flawlessly.
* Some competitive multiplayer games with strict anti-cheat protection systems read the USB hardware at the kernel level and might ignore synthetic events. This is an operating system limitation that could only be bypassed with a signed Apple `DriverKit Extension`, which is not viable for free distribution.

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.
