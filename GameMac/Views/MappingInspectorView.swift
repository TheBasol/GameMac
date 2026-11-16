import SwiftUI

@available(macOS 13.0, *)
struct MappingInspectorView: View {
    @ObservedObject var viewModel: GameMacViewModel
    let searchText: String
    let onSwitchToSticksTab: () -> Void

    @State private var activePopoverElementId: String? = nil

    private var duplicateKeyCodes: Set<UInt16> {
        var counts: [UInt16: Int] = [:]
        for code in viewModel.activeProfile.buttonMapping.values {
            counts[code, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    private var validationWarnings: [String] {
        var reverseMapping: [UInt16: [String]] = [:]
        for (element, keyCode) in viewModel.activeProfile.buttonMapping {
            reverseMapping[keyCode, default: []].append(element)
        }
        return reverseMapping
            .filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }
            .map { keyCode, elements in
                let names = elements.map { ControlCatalog.displayName(for: $0) }.joined(separator: ", ")
                return "\(KeyCodes.name(for: keyCode)) is shared by \(names)"
            }
    }

    private func elements(for category: ControlCategory) -> [ControlElementSpec] {
        let base = ControlCatalog.all.filter { $0.category == category }
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
            mappedNameMatches($0.id)
        }
    }

    private func mappedNameMatches(_ elementId: String) -> Bool {
        guard let code = viewModel.activeProfile.buttonMapping[elementId] else { return false }
        return KeyCodes.name(for: code).localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !validationWarnings.isEmpty {
                conflictBanner
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }

            ScrollViewReader { proxy in
                List {
                    ForEach(ControlCategory.allCases) { category in
                        categorySection(for: category)
                    }
                }
                .listStyle(.inset)
                .onChange(of: viewModel.selectedControlId) { newId in
                    guard let id = newId else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func categorySection(for category: ControlCategory) -> some View {
        if category == .leftStick && viewModel.leftStickMode != .keyboard {
            if searchText.isEmpty || category.rawValue.localizedCaseInsensitiveContains(searchText) {
                Section(category.rawValue) {
                    stickSummaryRow(side: .left, mode: viewModel.leftStickMode, presetTitle: "Switch to WASD")
                }
            }
        } else if category == .rightStick && viewModel.rightStickMode != .keyboard {
            if searchText.isEmpty || category.rawValue.localizedCaseInsensitiveContains(searchText) {
                Section(category.rawValue) {
                    stickSummaryRow(side: .right, mode: viewModel.rightStickMode, presetTitle: "Switch to Arrows")
                }
            }
        } else {
            let items = elements(for: category)
            if !items.isEmpty {
                Section(category.rawValue) {
                    ForEach(items) { element in
                        mappingRow(for: element)
                            .id(element.id)
                    }
                }
            }
        }
    }

    private func stickSummaryRow(side: StickSide, mode: StickInputMode, presetTitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: mode == .mouse ? "computermouse" : "circle.slash")
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode == .mouse ? "Assigned to Mouse Emulation" : "Stick Disabled")
                    .font(.callout.weight(.medium))
                Text(mode == .mouse ? "Moves cursor/camera. Adjust speed in Sticks & Mouse." : "No keyboard or mouse output.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(presetTitle) {
                viewModel.setStickMode(stick: side, mode: .keyboard)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 2)
    }

    private func mappingRow(for element: ControlElementSpec) -> some View {
        let mappedCode = viewModel.activeProfile.buttonMapping[element.id]
        let isConflict = mappedCode.map { duplicateKeyCodes.contains($0) } ?? false
        let isSelected = viewModel.selectedControlId == element.id

        return HStack(spacing: 10) {
            Text(element.displayName)
                .font(.callout)
                .foregroundColor(.primary)

            if isConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("This key is assigned to multiple controls")
            }

            Spacer()

            Button {
                viewModel.selectedControlId = element.id
                activePopoverElementId = element.id
            } label: {
                KeycapBadge(
                    keyCode: mappedCode,
                    isRecording: activePopoverElementId == element.id,
                    isHighlighted: isSelected
                )
            }
            .buttonStyle(.plain)
            .help("Click to assign a key or mouse button")
            .popover(
                isPresented: Binding(
                    get: { activePopoverElementId == element.id },
                    set: { isPresented in
                        if !isPresented && activePopoverElementId == element.id {
                            activePopoverElementId = nil
                        }
                    }
                ),
                arrowEdge: .leading
            ) {
                KeyCapturePopoverView(
                    element: element,
                    viewModel: viewModel,
                    onDismiss: {
                        activePopoverElementId = nil
                    }
                )
            }

            Menu {
                Button {
                    viewModel.updateMapping(for: element.id, to: 1000)
                } label: {
                    Label("Left Click", systemImage: "computermouse")
                }
                Button {
                    viewModel.updateMapping(for: element.id, to: 1001)
                } label: {
                    Label("Right Click", systemImage: "computermouse")
                }
                Button {
                    viewModel.updateMapping(for: element.id, to: 1002)
                } label: {
                    Label("Middle Click", systemImage: "computermouse")
                }
                Button {
                    viewModel.updateMapping(for: element.id, to: KeyCodes.escape)
                } label: {
                    Label("Escape ⎋", systemImage: "escape")
                }
                if mappedCode != nil {
                    Divider()
                    Button(role: .destructive) {
                        viewModel.updateMapping(for: element.id, to: nil)
                    } label: {
                        Label("Clear Mapping", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 22)
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedControlId = element.id
        }
    }

    private var conflictBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Shared Key Assignments")
                    .font(.caption.weight(.semibold))
                ForEach(validationWarnings, id: \.self) { warning in
                    Text("• \(warning)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}
