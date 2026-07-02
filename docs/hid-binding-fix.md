# HID Button Binding and Visualizer Fix (GameSir-K1)

Documentation regarding the issues encountered and fixes applied in June 2025.

---

## Reported Symptoms

1. **Raw USB connection failure** throwing `kr=-536870201` during step 6 (`IOCreatePlugInInterface`).
2. **Button binding exited listening mode** but the on-screen visualizer did not reflect the reassigned buttons.
3. The console printed `Successfully saved controller layout: generic` instead of the expected `3537_1058`.
4. Analog sticks and triggers functioned correctly in the visualizer; only buttons failed or displayed incorrect default mappings.

---

## Diagnostics

### Raw USB Error (`-536870201`)

IOKit Return Code: **`kIOReturnExclusiveAccess` (0xE00002C7)**.

The GameSir-K1 controller exposes:

| Interface | Class | Status |
|-----------|-------|--------|
| #0–#2 | 1 (Audio) | Ignored |
| #3 | 3 (HID) | Claimed by `IOHIDFamily` — not accessible via IOUSBLib |
| GIP | 255 | Not present on this hardware/mode |

The code was attempting to open the HID interface (Class 3) for raw USB communication, which macOS blocks once the system's own HID driver has claimed it.

**Fix:** `RawUSBGamepadManager` now specifically looks for interface **Class 255**. If it is not present, it terminates its thread loop quietly, allowing the active IOHIDManager connection path to proceed.

---

## Hardware Binding Issues

Three chained bugs prevented binding from registering:

### Bug 1: Active Layout Fell Back to `generic`
The layout JSON configs (`3537_1058.json`, etc.) **were not included in the app bundle resources** (the Resources phase of the generated Xcode project was empty). When trying to load the layout for the active device `3537_1058`, `LayoutManager` fell back to `genericLayout`.

### Bug 2: Binding Saved to the Wrong File
The binding listener obtained the layout via `manager.activeLayout` (which held `"generic"` as its key) and saved to:
```
~/Library/Application Support/GameMac/Layouts/generic.json
```
The actual physical device was looking for `3537_1058.json`.

### Bug 3: `reloadActiveLayout()` Overwrote Changes
After saving, the handler triggered `reloadActiveLayout()`, which reloaded the layout from disk/bundle/static fallbacks, **discarding** the modified layout held in memory.

### Bug 4: Conflicting Legacy Keys
The default layout mapped `"4": "buttonY"`. When re-binding usage `4` to `buttonX` using the composite key `0x00090004`, the legacy key `"4"` would still override it unless deleted.

### Bug 5: No HID Callback for Binding
Initially, only `GIPPacketParser` dispatched raw button events to the editor. The HID parser processed gamepad inputs but did not trigger editor binding callbacks.

---

## Changes Implemented

### Files Modified

| File | Change |
|------|--------|
| `HIDInputParser.swift` | Composite HID keys; `lookupButtonSemantic`; `bindingEnabled`; callback `(page, usage)`; element filtering |
| `HIDGamepadManager.swift` | `onHIDButtonPressed` separated from GIP; wired callbacks |
| `GameMacViewModel.swift` | Binding loads/saves layouts via `activeDevice.layoutKey`; removed `reloadActiveLayout` call post-save |
| `LayoutManager.swift` | Added default `gameSirK1XboxLayout` for `3537_1058`; updated `applyButtonBinding()` |
| `MappingEditorView.swift` | Displays `HW: 0x........` labels; added binding feedback banners |
| `RawUSBGamepadManager.swift` | Filters GIP Class 255 interface; clean IOReturn print logs |
| `GameMac.xcodeproj/project.pbxproj` | Included layout JSONs in the resources bundle |
| `setup_project.py` | Added layouts directory to recursive builder |

### Composite HID Key

```swift
static func elementKey(page: UInt32, usage: UInt32) -> Int {
    Int((page << 16) | usage)
}
```
Example: page `0x09`, usage `4` &rarr; `589828` &rarr; displayed as `0x00090004`.

### `applyButtonBinding`

When assigning a button:
1. Removes the previous composite key associated with the semantic element.
2. Deletes conflicting composite and legacy keys (on page `0x09`).
3. Writes the new composite mapping entry.

### Corrected Binding Flow

```
activeDevice.layoutKey → loadLayout(for: device)
  → applyButtonBinding(...)
  → saveLayout → ~/Library/.../Layouts/3537_1058.json
  → manager.activeLayout = activeLayout (On-the-fly hot reload)
  → activeControllerLayout updated in UI
```

### Expected Binding Console Log

```
[HID-BIND] Bound: page 0x09 usage 4 (0x00090004) → buttonX [layout: 3537_1058]
Successfully saved controller layout: 3537_1058
```

If layouts still fall back to `generic`, rebuild the project to bundle resources and delete any corrupted layout files:
```bash
rm ~/Library/Application\ Support/GameMac/Layouts/generic.json
```

---

## Verification

1. Connect the GameSir-K1 &rarr; Sticks should move in the UI visualizer.
2. Go to the Mapping Editor &rarr; Click the gamepad icon next to "X Button" &rarr; Press the physical X button on the gamepad.
3. The editor should display `HW: 0x00090004` (or actual usage key) under the button name.
4. Console outputs: `Successfully saved controller layout: 3537_1058`.
5. Visualizer lights up the X button correctly upon press.
6. Mapping a keyboard key on the right is a **separate** step for game emulation.

---

## Developer Guidelines

- **Do not trigger `reloadActiveLayout()` immediately after mutating and saving a layout** if the layout in memory is already correct.
- **Always use `activeDevice.layoutKey`** when writing hardware overrides. Never assume `manager.activeLayout.layoutKey` is set correctly.
- **Include `Resources/Layouts/*.json` in build resources**. `setup_project.py` handles this automatically.
- **Raw USB** only applies to controllers exposing class 255. Standard GameSir-K1 uses the HID path.
