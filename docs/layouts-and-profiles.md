# Hardware Layouts and Mapping Profiles

GameMac uses **two independent mapping systems**. Confusing them is the most common cause of "I assigned the button but nothing changed in the UI" support issues.

---

## Comparison

| Feature | Hardware Layout (`ControllerLayout`) | Mapping Profile (`MappingProfile`) |
|---|---|---|
| **Question answered** | Which physical signal corresponds to "button A"? | Which keyboard key corresponds to "button A" in the game? |
| **Map Key** | Composite HID integer or GIP bitmask | Semantic String (e.g., `"buttonA"`) |
| **Map Value** | Semantic String (e.g., `"buttonA"`) | macOS virtual keycode (UInt16) |
| **Edited via** | **Gamepad** icon in the Mapping Editor | **Keyboard** icon in the Mapping Editor |
| **Affects** | Hardware Visualizer & live mapping | Event injection into games/apps |
| **File Name** | `Layouts/<VID>_<PID>.json` | `Profiles/<name>.json` |
| **Runtime Location** | `~/Library/Application Support/GameMac/Layouts/` | `~/Library/Application Support/GameMac/Profiles/` |

---

## ControllerLayout (Hardware &rarr; Semantics)

Defined in [ControllerLayout.swift](file:///Users/enriquevazquez/Documents/Developer/GameMac/GameMac/Models/ControllerLayout.swift):

```json
{
  "layoutKey": "3537_1058",
  "deviceName": "GameSir-K1 Controller for Xbox",
  "axisMap": {
    "48": "leftStickX",
    "49": "leftStickY",
    "50": "rightStickX",
    "53": "rightStickY"
  },
  "buttonMap": {
    "589828": "buttonX"
  }
}
```

### `buttonMap` Keys (HID path)

| Type | Format | Example |
|------|--------|---------|
| **Composite (current)** | `(usagePage << 16) \| usage` | Usage page `0x09`, usage `4` &rarr; `589828` (`0x00090004`) |
| **Legacy** | Only `usage` on the Button page `0x09` | `"4": "buttonY"` |

The parser (`HIDInputParser.lookupButtonSemantic`) looks up the composite key first, falling back to the legacy key if not found.

### `buttonMap` Keys (GIP / raw USB path)

16-bit bitmasks representing button states in the GIP packet buttons word (`1`, `2`, `4`, `8`, etc.).

### `axisMap` Keys

Generic Desktop (`0x01`) usage IDs: `48` = X, `49` = Y, `50` = Z, `53` = Rz, etc.

---

## MappingProfile (Semantics &rarr; Keyboard/Mouse)

Defined in [MappingProfile.swift](file:///Users/enriquevazquez/Documents/Developer/GameMac/GameMac/Models/MappingProfile.swift):

```json
{
  "profileName": "FPS Shooter",
  "buttonMapping": {
    "buttonA": 49,
    "leftStickUp": 13,
    "rightStickRight": 1001
  },
  "deadZone": 0.15,
  "mouseSensitivity": 1.5,
  "mouseExponent": 1.2
}
```

- `49` = Space key (see [KeyCodes.swift](file:///Users/enriquevazquez/Documents/Developer/GameMac/GameMac/Engine/KeyCodes.swift)).
- `1000` / `1001` / `1002` = Left / Right / Middle Mouse Clicks.

---

## What the Mapping Editor Displays

| Column / Label | Meaning |
|----------------|---------|
| `HW: 0x........` under the control name | Hardware binding saved in the layout |
| `NO KEY` / Key name on the right | Profile mapping to keyboard/mouse |
| `PRESS GAMEPAD BUTTON...` | Active hardware binding listening mode |
| `PRESS ANY KEY...` | Active keyboard key binding listening mode |

It is **normal** for the right-hand column to remain on `NO KEY` after binding a physical gamepad button until you assign a keyboard key to it using the keyboard icon.

---

## What the Visualizer Displays

`ControllerVisualizer` reads from `GamepadState`, which is populated using the **hardware layout**, not the profile.

If the layout incorrectly maps a usage, the wrong button will light up on the screen, even if the keyboard mapping profile is working correctly in-game.

---

## Hardware Binding Flow (Summary)

1. User clicks the gamepad icon next to "X Button".
2. `bindingGamepadElementId = "buttonX"` &rarr; `HIDInputParser.bindingEnabled = true`.
3. User presses the physical button on the gamepad.
4. `HIDInputParser` detects `(page, usage)` and triggers `onHIDButtonPressed`.
5. `GamepadDriverService` loads the layout for the **active device** (e.g. `3537_1058`, not `generic`).
6. `LayoutManager.applyButtonBinding` updates `buttonMap`, removing any conflicting keys.
7. Saves to `~/Library/Application Support/GameMac/Layouts/3537_1058.json`.
8. Applies the layout on-the-fly to `HIDGamepadManager.activeLayout`.
9. The visualizer reflects the change on the next button press.

---

## Supported Devices by `layoutKey`

| layoutKey | VID | PID | Name |
|-----------|-----|-----|------|
| `3537_1012` | 0x3537 | 0x1012 | GameSir Kaleid K1 |
| `3537_1058` | 0x3537 | 0x1058 | GameSir-K1 Controller for Xbox |
| `generic` | * | * | Generic Fallback |

`layoutKey = String(format: "%04X_%04X", vendorID, productID)`.
