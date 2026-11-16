import SwiftUI

@available(macOS 13.0, *)
struct HardwareSetupSheet: View {
    @ObservedObject var viewModel: GameMacViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: SetupSection = .buttons
    @State private var confirmingLayoutReset = false

    enum SetupSection: String, CaseIterable {
        case buttons = "Physical Buttons"
        case calibration = "Axis Calibration"
    }

    private var hardwareElements: [ControlElementSpec] {
        ControlCatalog.all.filter(\.supportsHardwareBinding)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Controller Hardware Setup")
                        .font(.title3.weight(.semibold))

                    if let device = viewModel.activeDevice {
                        Text("\(device.name) • VID \(String(format: "%04X", device.vendorID)) / PID \(String(format: "%04X", device.productID))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Connect a controller to configure physical inputs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Picker("", selection: $selectedSection) {
                    ForEach(SetupSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
            .padding(16)

            Divider()

            if let device = viewModel.activeDevice {
                if selectedSection == .buttons {
                    physicalButtonsTab(for: device)
                } else {
                    axisCalibrationTab(for: device)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Active Controller")
                        .font(.headline)
                    Text("Plug in your gamepad via USB or Bluetooth to rebind hardware layouts or calibrate axes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            // Footer
            HStack {
                if selectedSection == .buttons, viewModel.activeDevice != nil {
                    Button("Restore Default Layout…") {
                        confirmingLayoutReset = true
                    }
                }

                Spacer()

                Button("Done") {
                    viewModel.bindingGamepadElementId = nil
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
        }
        .frame(width: 600, height: 500)
        .onDisappear {
            viewModel.bindingGamepadElementId = nil
            viewModel.setRawTelemetryEnabled(false)
        }
        .alert("Restore Default Hardware Layout?", isPresented: $confirmingLayoutReset) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                viewModel.resetActiveHardwareLayout()
            }
        } message: {
            Text("Discards custom physical button overrides for this controller and reloads the built-in layout.")
        }
    }

    // MARK: - Physical Buttons Tab

    private func physicalButtonsTab(for device: DeviceInfo) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Use this only if physical buttons on your controller register as the wrong button in the preview diagram (for example, A and B swapped).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let msg = viewModel.lastHardwareBindingMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(msg)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.green.opacity(0.10))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            List(hardwareElements) { element in
                let isListening = viewModel.bindingGamepadElementId == element.id
                let hwLabel = hardwareBindingLabel(for: element.id)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(element.displayName)
                            .font(.callout.weight(.medium))
                        Text(hwLabel ?? "Not mapped in layout")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isListening {
                        Button("Cancel (Press Controller Button…)") {
                            viewModel.bindingGamepadElementId = nil
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else {
                        Button("Rebind Physical…") {
                            viewModel.bindingGamepadElementId = element.id
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
        .onAppear {
            viewModel.setRawTelemetryEnabled(false)
        }
    }

    // MARK: - Axis Calibration Tab

    private func axisCalibrationTab(for device: DeviceInfo) -> some View {
        let layout = LayoutManager.shared.loadLayout(for: device)
        let sortedAxes = layout.axisMap.sorted { $0.key < $1.key }

        return VStack(spacing: 0) {
            Text("Override logical Min/Max bounds if a stick or trigger never reaches 100% or fails to center. Move the control across its full range while using Auto-Calibrate.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            List(sortedAxes, id: \.key) { usage, axisName in
                AxisCalibrationRow(
                    layoutKey: layout.layoutKey,
                    usage: usage,
                    name: axisName,
                    liveRawValue: viewModel.liveRawAxisValues[usage]
                )
            }
            .listStyle(.inset)
        }
        .onAppear {
            viewModel.setRawTelemetryEnabled(true)
        }
    }

    private func hardwareBindingLabel(for elementId: String) -> String? {
        guard let layout = viewModel.activeControllerLayout else { return nil }

        if let buttonKey = layout.buttonMap.first(where: { $0.value == elementId })?.key {
            return "Button \(HIDInputParser.formatElementKey(buttonKey))"
        }

        let axisName: String?
        switch elementId {
        case "leftTriggerButton": axisName = "leftTrigger"
        case "rightTriggerButton": axisName = "rightTrigger"
        default: axisName = nil
        }

        if let axisName = axisName,
           let axisKey = layout.axisMap.first(where: { $0.value == axisName })?.key {
            return "Axis \(HIDInputParser.formatAxisKey(axisKey))"
        }

        return nil
    }
}

@available(macOS 13.0, *)
private struct AxisCalibrationRow: View {
    let layoutKey: String
    let usage: Int
    let name: String
    let liveRawValue: Int?

    @State private var minVal: Int = 0
    @State private var maxVal: Int = 255
    @State private var isAutoCalibrating = false
    @State private var observedMin: Int = Int.max
    @State private var observedMax: Int = Int.min
    @State private var savedBadge = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(prettifyAxisName(name))
                    .font(.callout.weight(.medium))

                HStack(spacing: 8) {
                    Text(String(format: "Usage 0x%02X", usage))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let raw = liveRawValue {
                        Text("Raw: \(raw)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                }
            }

            Spacer()

            if isAutoCalibrating {
                Text("Min \(observedMin == Int.max ? "–" : "\(observedMin)") / Max \(observedMax == Int.min ? "–" : "\(observedMax)")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.orange)

                Button("Apply Range") {
                    if observedMin < observedMax {
                        minVal = observedMin
                        maxVal = observedMax
                        save()
                    }
                    isAutoCalibrating = false
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .disabled(observedMin >= observedMax)

                Button("Cancel") {
                    isAutoCalibrating = false
                }
                .controlSize(.small)
            } else {
                HStack(spacing: 6) {
                    Text("Min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Min", value: $minVal, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .onSubmit { save() }

                    Text("Max")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Max", value: $maxVal, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .onSubmit { save() }

                    Button("Auto") {
                        observedMin = liveRawValue ?? Int.max
                        observedMax = liveRawValue ?? Int.min
                        isAutoCalibrating = true
                    }
                    .controlSize(.small)
                    .help("Move the stick or trigger across its full range to detect Min and Max")

                    Button(savedBadge ? "Saved" : "Save") {
                        save()
                    }
                    .controlSize(.small)
                    .disabled(minVal >= maxVal)

                    Button("Reset") {
                        CalibrationManager.shared.removeCalibration(layoutKey: layoutKey, usage: usage)
                        minVal = 0
                        maxVal = 255
                        savedBadge = false
                    }
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 3)
        .onAppear {
            loadCurrent()
        }
        .onChange(of: liveRawValue) { newRaw in
            guard isAutoCalibrating, let raw = newRaw else { return }
            if raw < observedMin { observedMin = raw }
            if raw > observedMax { observedMax = raw }
        }
    }

    private func prettifyAxisName(_ name: String) -> String {
        var result = ""
        for char in name {
            if char.isUppercase {
                result += " \(char)"
            } else if result.isEmpty {
                result += char.uppercased()
            } else {
                result += String(char)
            }
        }
        return result
    }

    private func loadCurrent() {
        if let cal = CalibrationManager.shared.getCalibration(layoutKey: layoutKey, usage: usage) {
            minVal = cal.min
            maxVal = cal.max
        } else {
            minVal = 0
            maxVal = 255
        }
    }

    private func save() {
        guard minVal < maxVal else { return }
        CalibrationManager.shared.saveCalibration(layoutKey: layoutKey, usage: usage, min: minVal, max: maxVal)
        savedBadge = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            savedBadge = false
        }
    }
}
