# GameMac Documentation

Index of the project documentation.

| Document | Description |
|----------|-------------|
| [application.md](application.md) | Detailed application description: architecture, components, data flows, UI, profiles, and permissions |
| [hid-binding-fix.md](hid-binding-fix.md) | HID button binding and visualizer fix for the GameSir-K1 (June 2025) |
| [device-detection-and-cemu-sdl-fix.md](device-detection-and-cemu-sdl-fix.md) | Controller auto-detection fix in RawUSBGamepadManager and SDL2 (SDLController) compatibility (September 2026) |
| [layouts-and-profiles.md](layouts-and-profiles.md) | Difference between hardware layouts and mapping profiles; JSON formats and file locations |

## Quick Summary

**GameMac** is a native bridge for macOS 13+ that reads inputs from USB gamepads (via standard HID and optionally raw GIP USB) and translates them into virtual keyboard and mouse events using `CGEvent`. This allows games and apps that do not natively recognize the controller to receive input.

The primary use case is the **GameSir Kaleid K1** / **GameSir-K1 Controller for Xbox** (VID `0x3537`), which macOS does not expose as a standard game controller.

## How to Build and Run

```bash
python3 setup_project.py
open GameMac.xcodeproj
# Press Cmd + R in Xcode to build & run
```

See also the main repository [README](../README.md) for Accessibility permissions instructions and compatibility notes.
