import SwiftUI
import AppKit

/// Categorizes semantic controller elements for grouped UI presentation.
enum ControlCategory: String, CaseIterable, Identifiable {
    case face = "Face Buttons"
    case shoulders = "Bumpers & Triggers"
    case dpad = "D-Pad"
    case leftStick = "Left Stick"
    case rightStick = "Right Stick"
    case system = "System Buttons"

    var id: String { rawValue }
}

/// Metadata describing a mappable semantic controller input.
struct ControlElementSpec: Identifiable, Hashable {
    let id: String
    let displayName: String
    let shortLabel: String
    let category: ControlCategory
    let supportsHardwareBinding: Bool

    init(
        id: String,
        displayName: String,
        shortLabel: String,
        category: ControlCategory,
        supportsHardwareBinding: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.shortLabel = shortLabel
        self.category = category
        self.supportsHardwareBinding = supportsHardwareBinding
    }
}

enum ControlCatalog {
    static let all: [ControlElementSpec] = [
        ControlElementSpec(id: "buttonA", displayName: "A Button", shortLabel: "A", category: .face),
        ControlElementSpec(id: "buttonB", displayName: "B Button", shortLabel: "B", category: .face),
        ControlElementSpec(id: "buttonX", displayName: "X Button", shortLabel: "X", category: .face),
        ControlElementSpec(id: "buttonY", displayName: "Y Button", shortLabel: "Y", category: .face),

        ControlElementSpec(id: "leftBumper", displayName: "Left Bumper", shortLabel: "LB", category: .shoulders),
        ControlElementSpec(id: "rightBumper", displayName: "Right Bumper", shortLabel: "RB", category: .shoulders),
        ControlElementSpec(id: "leftTriggerButton", displayName: "Left Trigger", shortLabel: "LT", category: .shoulders),
        ControlElementSpec(id: "rightTriggerButton", displayName: "Right Trigger", shortLabel: "RT", category: .shoulders),

        ControlElementSpec(id: "dpadUp", displayName: "D-Pad Up", shortLabel: "Up", category: .dpad),
        ControlElementSpec(id: "dpadDown", displayName: "D-Pad Down", shortLabel: "Down", category: .dpad),
        ControlElementSpec(id: "dpadLeft", displayName: "D-Pad Left", shortLabel: "Left", category: .dpad),
        ControlElementSpec(id: "dpadRight", displayName: "D-Pad Right", shortLabel: "Right", category: .dpad),

        ControlElementSpec(id: "leftStickUp", displayName: "Left Stick Up", shortLabel: "LS ↑", category: .leftStick, supportsHardwareBinding: false),
        ControlElementSpec(id: "leftStickDown", displayName: "Left Stick Down", shortLabel: "LS ↓", category: .leftStick, supportsHardwareBinding: false),
        ControlElementSpec(id: "leftStickLeft", displayName: "Left Stick Left", shortLabel: "LS ←", category: .leftStick, supportsHardwareBinding: false),
        ControlElementSpec(id: "leftStickRight", displayName: "Left Stick Right", shortLabel: "LS →", category: .leftStick, supportsHardwareBinding: false),

        ControlElementSpec(id: "rightStickUp", displayName: "Right Stick Up", shortLabel: "RS ↑", category: .rightStick, supportsHardwareBinding: false),
        ControlElementSpec(id: "rightStickDown", displayName: "Right Stick Down", shortLabel: "RS ↓", category: .rightStick, supportsHardwareBinding: false),
        ControlElementSpec(id: "rightStickLeft", displayName: "Right Stick Left", shortLabel: "RS ←", category: .rightStick, supportsHardwareBinding: false),
        ControlElementSpec(id: "rightStickRight", displayName: "Right Stick Right", shortLabel: "RS →", category: .rightStick, supportsHardwareBinding: false),

        ControlElementSpec(id: "select", displayName: "Select / View", shortLabel: "View", category: .system),
        ControlElementSpec(id: "start", displayName: "Start / Menu", shortLabel: "Menu", category: .system),
        ControlElementSpec(id: "home", displayName: "Home / Logo", shortLabel: "Home", category: .system)
    ]

    static func spec(for id: String) -> ControlElementSpec? {
        all.first { $0.id == id }
    }

    static func displayName(for id: String) -> String {
        spec(for: id)?.displayName ?? id
    }
}

/// Manages a safe local NSEvent monitor for capturing keyboard keys and modifier keys.
@MainActor
final class KeyCaptureSession: ObservableObject {
    @Published private(set) var isListening = false
    private var monitor: Any?

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func start(onCapture: @escaping (UInt16) -> Void, onCancel: @escaping () -> Void) {
        stop()
        isListening = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }

            if event.type == .keyDown {
                if event.keyCode == KeyCodes.escape {
                    self.stop()
                    onCancel()
                    return nil
                }
                let captured = event.keyCode
                self.stop()
                onCapture(captured)
                return nil
            }

            if event.type == .flagsChanged, let modifierKeyCode = Self.pressedModifierKeyCode(from: event) {
                self.stop()
                onCapture(modifierKeyCode)
                return nil
            }

            return event
        }
    }

    func stop() {
        isListening = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private static func pressedModifierKeyCode(from event: NSEvent) -> UInt16? {
        let code = event.keyCode
        let flags = event.modifierFlags
        switch code {
        case KeyCodes.shift, KeyCodes.rightShift:
            return flags.contains(.shift) ? code : nil
        case KeyCodes.control, KeyCodes.rightControl:
            return flags.contains(.control) ? code : nil
        case KeyCodes.option, KeyCodes.rightOption:
            return flags.contains(.option) ? code : nil
        case KeyCodes.command, 0x36:
            return flags.contains(.command) ? code : nil
        case KeyCodes.capsLock:
            return flags.contains(.capsLock) ? code : nil
        case KeyCodes.function:
            return flags.contains(.function) ? code : nil
        default:
            return nil
        }
    }
}

/// Native macOS-style tactile keycap badge adaptive to Light and Dark appearance.
struct KeycapBadge: View {
    let keyCode: UInt16?
    var compact: Bool = false
    var isRecording: Bool = false
    var isHighlighted: Bool = false

    var body: some View {
        Group {
            if isRecording {
                Text("Press Key…")
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, compact ? 6 : 8)
                    .padding(.vertical, compact ? 2 : 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 1)
                    )
            } else if let code = keyCode {
                Text(compact ? KeyCodes.shortLabel(for: code) : KeyCodes.name(for: code))
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isHighlighted ? .white : .primary)
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 6 : 8)
                    .padding(.vertical, compact ? 2 : 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isHighlighted ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(isHighlighted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 0.5, x: 0, y: 1)
            } else {
                Text("Unassigned")
                    .font(.system(size: compact ? 9.5 : 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, compact ? 5 : 8)
                    .padding(.vertical, compact ? 2 : 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.18))
                    )
            }
        }
    }
}

/// Shared popover for binding any controller element directly from the diagram or inspector.
@available(macOS 13.0, *)
struct KeyCapturePopoverView: View {
    let element: ControlElementSpec
    @ObservedObject var viewModel: GameMacViewModel
    let onDismiss: () -> Void

    @StateObject private var captureSession = KeyCaptureSession()

    private var currentKeyCode: UInt16? {
        viewModel.activeProfile.buttonMapping[element.id]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(element.displayName)
                        .font(.headline)
                    Text(element.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                KeycapBadge(keyCode: currentKeyCode, isRecording: captureSession.isListening)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    if captureSession.isListening {
                        captureSession.stop()
                    } else {
                        startCapture()
                    }
                } label: {
                    Label(
                        captureSession.isListening ? "Listening… Press Key (Esc to Cancel)" : "Record Keyboard or Modifier Key",
                        systemImage: captureSession.isListening ? "keyboard.badge.ellipsis" : "keyboard"
                    )
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(captureSession.isListening ? .orange : .accentColor)

                Text("Supports letters, numbers, arrows, function keys, and Shift / Control / Option / Command.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Assignments")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    quickButton("L-Click", code: 1000)
                    quickButton("R-Click", code: 1001)
                    quickButton("M-Click", code: 1002)
                }
                HStack(spacing: 6) {
                    quickButton("Space ␣", code: KeyCodes.space)
                    quickButton("Shift ⇧", code: KeyCodes.shift)
                    quickButton("Esc ⎋", code: KeyCodes.escape)
                }
            }

            if currentKeyCode != nil {
                Divider()
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        captureSession.stop()
                        viewModel.updateMapping(for: element.id, to: nil)
                        onDismiss()
                    } label: {
                        Label("Clear Mapping", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
        .onAppear {
            startCapture()
        }
        .onDisappear {
            captureSession.stop()
        }
    }

    private func startCapture() {
        captureSession.start(
            onCapture: { keyCode in
                viewModel.updateMapping(for: element.id, to: keyCode)
                onDismiss()
            },
            onCancel: {
                // Keep popover open so user can pick a quick button or close manually
            }
        )
    }

    private func quickButton(_ title: String, code: UInt16) -> some View {
        Button(title) {
            captureSession.stop()
            viewModel.updateMapping(for: element.id, to: code)
            onDismiss()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .frame(maxWidth: .infinity)
    }
}
