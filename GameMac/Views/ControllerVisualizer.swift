import SwiftUI

@available(macOS 13.0, *)
struct ControllerVisualizer: View {
    @ObservedObject var viewModel: GameMacViewModel
    let onOpenHardwareSetup: () -> Void
    let onSwitchToSticksTab: () -> Void

    @State private var activePopoverElementId: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack(spacing: 10) {
                Image(systemName: viewModel.gamepadState.isConnected ? "gamecontroller.fill" : "gamecontroller")
                    .font(.title3)
                    .foregroundColor(viewModel.gamepadState.isConnected ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.activeDevice?.name ?? "Controller Preview")
                        .font(.headline)
                        .lineLimit(1)

                    Text("Click any button on the diagram to assign a key or mouse click")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                connectionStatusPill
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Main Interactive Diagram
            Spacer(minLength: 10)

            VStack(spacing: 18) {
                // Triggers & Bumpers
                HStack(spacing: 110) {
                    VStack(spacing: 6) {
                        interactiveTrigger(
                            elementId: "leftTriggerButton",
                            label: "LT",
                            value: viewModel.gamepadState.leftTrigger,
                            isPressed: viewModel.gamepadState.leftTriggerButton
                        )
                        interactiveBumper(
                            elementId: "leftBumper",
                            label: "LB",
                            isPressed: viewModel.gamepadState.leftBumper
                        )
                    }

                    VStack(spacing: 6) {
                        interactiveTrigger(
                            elementId: "rightTriggerButton",
                            label: "RT",
                            value: viewModel.gamepadState.rightTrigger,
                            isPressed: viewModel.gamepadState.rightTriggerButton
                        )
                        interactiveBumper(
                            elementId: "rightBumper",
                            label: "RB",
                            isPressed: viewModel.gamepadState.rightBumper
                        )
                    }
                }

                // Body: Left Controls | Center System | Right Controls
                HStack(alignment: .center, spacing: 26) {
                    // Left Side: Left Stick + D-Pad
                    VStack(spacing: 16) {
                        stickCluster(
                            side: .left,
                            x: viewModel.gamepadState.leftStickX,
                            y: viewModel.gamepadState.leftStickY,
                            mode: viewModel.leftStickMode
                        )
                        dpadCluster
                    }

                    // Center System Controls
                    HStack(spacing: 10) {
                        interactiveSystemButton(
                            elementId: "select",
                            label: "View",
                            icon: "rectangle.on.rectangle",
                            isPressed: viewModel.gamepadState.select
                        )

                        interactiveSystemButton(
                            elementId: "home",
                            label: "Home",
                            icon: "circle.grid.cross.fill",
                            isPressed: viewModel.gamepadState.home
                        )

                        interactiveSystemButton(
                            elementId: "start",
                            label: "Menu",
                            icon: "line.3.horizontal",
                            isPressed: viewModel.gamepadState.start
                        )
                    }
                    .padding(.vertical, 8)

                    // Right Side: Face Buttons + Right Stick
                    VStack(spacing: 16) {
                        faceButtonsCluster
                        stickCluster(
                            side: .right,
                            x: viewModel.gamepadState.rightStickX,
                            y: viewModel.gamepadState.rightStickY,
                            mode: viewModel.rightStickMode
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Spacer(minLength: 10)

            Divider()

            // Footer summary bar
            HStack(spacing: 10) {
                Label(
                    "\(viewModel.activeProfile.buttonMapping.count) mapped",
                    systemImage: "keyboard"
                )
                .font(.caption)
                .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Mouse: \(viewModel.isFpsMode ? "FPS Relative" : "Desktop Cursor")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Hardware Setup…") {
                    onOpenHardwareSetup()
                }
                .buttonStyle(.link)
                .font(.caption)
                .disabled(viewModel.activeDevice == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var connectionStatusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 7, height: 7)

            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.18))
        )
    }

    private var statusDotColor: Color {
        if !viewModel.isDriverRunning {
            return .orange
        }
        return viewModel.gamepadState.isConnected ? .green : .secondary
    }

    private var statusText: String {
        if !viewModel.isDriverRunning {
            return "Mapping Paused"
        }
        return viewModel.gamepadState.isConnected ? "Connected" : "No Controller"
    }

    @ViewBuilder
    private func interactiveTrigger(
        elementId: String,
        label: String,
        value: Double,
        isPressed: Bool
    ) -> some View {
        let mappedCode = viewModel.activeProfile.buttonMapping[elementId]
        let isSelected = viewModel.selectedControlId == elementId

        Button {
            openPopover(for: elementId)
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: 76, height: 32)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(isPressed ? 0.85 : 0.45))
                        .frame(width: 76, height: max(0, min(1, CGFloat(value)) * 32))

                    HStack(spacing: 4) {
                        Text(label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(isPressed ? .white : .primary)

                        if let code = mappedCode {
                            Text(KeyCodes.shortLabel(for: code))
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                                )
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(height: 32)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSelected || isPressed ? Color.accentColor : Color(nsColor: .separatorColor),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
            }
        }
        .buttonStyle(.plain)
        .help("Assign mapping for \(ControlCatalog.displayName(for: elementId))")
        .popover(isPresented: popoverBinding(for: elementId), arrowEdge: .bottom) {
            popoverView(for: elementId)
        }
    }

    @ViewBuilder
    private func interactiveBumper(
        elementId: String,
        label: String,
        isPressed: Bool
    ) -> some View {
        let mappedCode = viewModel.activeProfile.buttonMapping[elementId]
        let isSelected = viewModel.selectedControlId == elementId

        Button {
            openPopover(for: elementId)
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                if let code = mappedCode {
                    Text(KeyCodes.shortLabel(for: code))
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(isPressed ? Color.white.opacity(0.22) : Color(nsColor: .windowBackgroundColor))
                        )
                }
            }
            .foregroundColor(isPressed ? .white : .primary)
            .frame(width: 76, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isPressed ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isSelected || isPressed ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Assign mapping for \(ControlCatalog.displayName(for: elementId))")
        .popover(isPresented: popoverBinding(for: elementId), arrowEdge: .bottom) {
            popoverView(for: elementId)
        }
    }

    private func stickCluster(
        side: StickSide,
        x: Double,
        y: Double,
        mode: StickInputMode
    ) -> some View {
        let socketSize: CGFloat = 78
        let maxTravel: CGFloat = 22
        let deadZoneDiameter = socketSize * CGFloat(viewModel.deadZone)
        let isActive = hypot(x, y) > viewModel.deadZone

        return VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: socketSize, height: socketSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                // Dead zone boundary indicator
                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: deadZoneDiameter, height: deadZoneDiameter)
                    .overlay(
                        Circle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .foregroundColor(.secondary.opacity(0.45))
                    )

                // Thumb cap
                Circle()
                    .fill(isActive ? Color.accentColor.opacity(0.22) : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .strokeBorder(isActive ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isActive ? 1.5 : 1)
                    )
                    .overlay(
                        Text(side == .left ? "LS" : "RS")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(isActive ? .accentColor : .secondary)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 1.5, x: 0, y: 1)
                    .offset(x: CGFloat(x) * maxTravel, y: CGFloat(-y) * maxTravel)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.75), value: x)
                    .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.75), value: y)
            }

            Button {
                onSwitchToSticksTab()
            } label: {
                Text(stickModeBadge(side: side, mode: mode))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.75)
                    )
            }
            .buttonStyle(.plain)
            .help("Configure \(side.rawValue) in Sticks & Mouse")
        }
    }

    private func stickModeBadge(side: StickSide, mode: StickInputMode) -> String {
        switch mode {
        case .mouse:
            return "Mouse"
        case .disabled:
            return "Disabled"
        case .keyboard:
            let keys = side.directionalKeys
            let mapping = viewModel.activeProfile.buttonMapping
            let u = mapping[keys.up].map { KeyCodes.shortLabel(for: $0) } ?? "·"
            let l = mapping[keys.left].map { KeyCodes.shortLabel(for: $0) } ?? "·"
            let d = mapping[keys.down].map { KeyCodes.shortLabel(for: $0) } ?? "·"
            let r = mapping[keys.right].map { KeyCodes.shortLabel(for: $0) } ?? "·"
            return "\(u)\(l)\(d)\(r)"
        }
    }

    private var dpadCluster: some View {
        ZStack {
            // Cross background plate
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: 72, height: 24)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: 24, height: 72)

            dpadArm(elementId: "dpadUp", icon: "chevron.up", isPressed: viewModel.gamepadState.dpadUp)
                .offset(y: -24)
            dpadArm(elementId: "dpadDown", icon: "chevron.down", isPressed: viewModel.gamepadState.dpadDown)
                .offset(y: 24)
            dpadArm(elementId: "dpadLeft", icon: "chevron.left", isPressed: viewModel.gamepadState.dpadLeft)
                .offset(x: -24)
            dpadArm(elementId: "dpadRight", icon: "chevron.right", isPressed: viewModel.gamepadState.dpadRight)
                .offset(x: 24)

            Circle()
                .fill(Color(nsColor: .separatorColor).opacity(0.4))
                .frame(width: 8, height: 8)
        }
        .frame(width: 78, height: 78)
    }

    @ViewBuilder
    private func dpadArm(elementId: String, icon: String, isPressed: Bool) -> some View {
        let mappedCode = viewModel.activeProfile.buttonMapping[elementId]
        let isSelected = viewModel.selectedControlId == elementId

        Button {
            openPopover(for: elementId)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isPressed ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                isSelected || isPressed ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isSelected ? 1.5 : 0.75
                            )
                    )

                if let code = mappedCode {
                    Text(KeyCodes.shortLabel(for: code))
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(isPressed ? .white : .primary)
                        .lineLimit(1)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isPressed ? .white : .secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Assign mapping for \(ControlCatalog.displayName(for: elementId))")
        .popover(isPresented: popoverBinding(for: elementId), arrowEdge: .trailing) {
            popoverView(for: elementId)
        }
    }

    private var faceButtonsCluster: some View {
        ZStack {
            faceButton(elementId: "buttonY", label: "Y", isPressed: viewModel.gamepadState.buttonY, pressColor: .yellow, badgeAlignment: .top)
                .offset(y: -25)
            faceButton(elementId: "buttonX", label: "X", isPressed: viewModel.gamepadState.buttonX, pressColor: .blue, badgeAlignment: .leading)
                .offset(x: -25)
            faceButton(elementId: "buttonB", label: "B", isPressed: viewModel.gamepadState.buttonB, pressColor: .red, badgeAlignment: .trailing)
                .offset(x: 25)
            faceButton(elementId: "buttonA", label: "A", isPressed: viewModel.gamepadState.buttonA, pressColor: .green, badgeAlignment: .bottom)
                .offset(y: 25)
        }
        .frame(width: 96, height: 96)
    }

    private enum BadgePlacement {
        case top, bottom, leading, trailing
    }

    @ViewBuilder
    private func faceButton(
        elementId: String,
        label: String,
        isPressed: Bool,
        pressColor: Color,
        badgeAlignment: BadgePlacement
    ) -> some View {
        let mappedCode = viewModel.activeProfile.buttonMapping[elementId]
        let isSelected = viewModel.selectedControlId == elementId

        Button {
            openPopover(for: elementId)
        } label: {
            ZStack {
                Circle()
                    .fill(isPressed ? pressColor : Color(nsColor: .windowBackgroundColor))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.accentColor : (isPressed ? pressColor : Color(nsColor: .separatorColor)),
                                lineWidth: isSelected ? 1.8 : 1
                            )
                    )
                    .overlay(
                        Text(label)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(isPressed ? .white : .primary)
                    )

                if let code = mappedCode {
                    Text(KeyCodes.shortLabel(for: code))
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.75)
                        )
                        .offset(badgeOffset(for: badgeAlignment))
                }
            }
        }
        .buttonStyle(.plain)
        .help("Assign mapping for \(ControlCatalog.displayName(for: elementId))")
        .popover(isPresented: popoverBinding(for: elementId), arrowEdge: .leading) {
            popoverView(for: elementId)
        }
    }

    private func badgeOffset(for placement: BadgePlacement) -> CGSize {
        switch placement {
        case .top: return CGSize(width: 0, height: -20)
        case .bottom: return CGSize(width: 0, height: 20)
        case .leading: return CGSize(width: -22, height: 0)
        case .trailing: return CGSize(width: 22, height: 0)
        }
    }

    @ViewBuilder
    private func interactiveSystemButton(
        elementId: String,
        label: String,
        icon: String,
        isPressed: Bool
    ) -> some View {
        let mappedCode = viewModel.activeProfile.buttonMapping[elementId]
        let isSelected = viewModel.selectedControlId == elementId

        Button {
            openPopover(for: elementId)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isPressed ? .white : .primary)
                    .frame(width: 28, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isPressed ? Color.accentColor : Color(nsColor: .windowBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected || isPressed ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isSelected ? 1.5 : 0.75
                            )
                    )

                if let code = mappedCode {
                    Text(KeyCodes.shortLabel(for: code))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                } else {
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help("Assign mapping for \(ControlCatalog.displayName(for: elementId))")
        .popover(isPresented: popoverBinding(for: elementId), arrowEdge: .bottom) {
            popoverView(for: elementId)
        }
    }

    // MARK: - Popover Helpers

    private func openPopover(for elementId: String) {
        viewModel.selectedControlId = elementId
        activePopoverElementId = elementId
    }

    private func popoverBinding(for elementId: String) -> Binding<Bool> {
        Binding(
            get: { activePopoverElementId == elementId },
            set: { isPresented in
                if !isPresented && activePopoverElementId == elementId {
                    activePopoverElementId = nil
                }
            }
        )
    }

    @ViewBuilder
    private func popoverView(for elementId: String) -> some View {
        if let spec = ControlCatalog.spec(for: elementId) {
            KeyCapturePopoverView(
                element: spec,
                viewModel: viewModel,
                onDismiss: {
                    activePopoverElementId = nil
                }
            )
        }
    }
}
