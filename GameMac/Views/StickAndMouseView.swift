import SwiftUI

@available(macOS 13.0, *)
struct StickAndMouseView: View {
    @ObservedObject var viewModel: GameMacViewModel

    private var activeMouseStickMagnitude: Double {
        let rx = viewModel.gamepadState.rightStickX
        let ry = viewModel.gamepadState.rightStickY
        let lx = viewModel.gamepadState.leftStickX
        let ly = viewModel.gamepadState.leftStickY

        if viewModel.rightStickMode == .mouse {
            let rMag = min(1.0, hypot(rx, ry))
            if rMag > 0.01 || viewModel.leftStickMode != .mouse {
                return rMag
            }
        }
        if viewModel.leftStickMode == .mouse {
            return min(1.0, hypot(lx, ly))
        }
        return 0.0
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Left Stick") {
                    Picker("Left Stick", selection: Binding(
                        get: { viewModel.leftStickMode },
                        set: { viewModel.setStickMode(stick: .left, mode: $0) }
                    )) {
                        ForEach(StickInputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                LabeledContent("Right Stick") {
                    Picker("Right Stick", selection: Binding(
                        get: { viewModel.rightStickMode },
                        set: { viewModel.setStickMode(stick: .right, mode: $0) }
                    )) {
                        ForEach(StickInputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            } header: {
                Text("Stick Assignments")
            } footer: {
                Text("Switching a stick to Keyboard automatically preloads W/A/S/D (Left) or Arrow keys (Right) if empty, which you can customize in Mappings.")
            }

            Section {
                Picker("Mouse Mode", selection: Binding(
                    get: { viewModel.isFpsMode },
                    set: { viewModel.setMouseMode(isFpsMode: $0) }
                )) {
                    Text("Desktop Cursor").tag(false)
                    Text("FPS Raw Delta").tag(true)
                }
                .pickerStyle(.segmented)

                Text(
                    viewModel.isFpsMode
                        ? "Sends relative mouse deltas for 3D cameras and first-person games while keeping your physical mouse usable."
                        : "Moves the macOS pointer within screen boundaries for menus, cursors, and 2D games."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("Mouse Emulation")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Stick Dead Zone")
                        Spacer()
                        Text(String(format: "%d%%", Int(viewModel.deadZone * 100)))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.deadZone, in: 0.05...0.35, step: 0.01)
                        .onChange(of: viewModel.deadZone) { _ in
                            viewModel.saveCurrentProfile()
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Mouse Sensitivity")
                        Spacer()
                        Text(String(format: "%.1fx", viewModel.mouseSensitivity))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.mouseSensitivity, in: 0.5...3.5, step: 0.1)
                        .onChange(of: viewModel.mouseSensitivity) { _ in
                            viewModel.saveCurrentProfile()
                        }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Response Curve Exponent")
                        Spacer()
                        Text(String(format: "%.1f", viewModel.mouseExponent))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.mouseExponent, in: 1.0...2.5, step: 0.1)
                        .onChange(of: viewModel.mouseExponent) { _ in
                            viewModel.saveCurrentProfile()
                        }
                }
            } header: {
                Text("Precision & Sensitivity")
            }

            Section {
                ResponseCurveView(
                    deadZone: viewModel.deadZone,
                    exponent: viewModel.mouseExponent,
                    liveInput: activeMouseStickMagnitude
                )
                .frame(height: 130)
                .padding(.vertical, 4)
            } header: {
                Text("Response Curve Preview")
            } footer: {
                Text("Higher exponents allow fine aim near center while preserving fast turns at full tilt.")
            }
        }
        .formStyle(.grouped)
    }
}

/// Plots the stick dead zone and exponential velocity curve with a live input marker.
@available(macOS 13.0, *)
struct ResponseCurveView: View {
    let deadZone: Double
    let exponent: Double
    let liveInput: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let pad: CGFloat = 8
            let plotRect = rect.insetBy(dx: pad, dy: pad)

            // Subtle frame & grid
            let gridColor = Color(nsColor: .separatorColor).opacity(0.5)
            for fraction in [0.25, 0.5, 0.75] {
                let x = plotRect.minX + plotRect.width * fraction
                let y = plotRect.minY + plotRect.height * fraction
                var vLine = Path()
                vLine.move(to: CGPoint(x: x, y: plotRect.minY))
                vLine.addLine(to: CGPoint(x: x, y: plotRect.maxY))
                context.stroke(vLine, with: .color(gridColor), lineWidth: 0.5)

                var hLine = Path()
                hLine.move(to: CGPoint(x: plotRect.minX, y: y))
                hLine.addLine(to: CGPoint(x: plotRect.maxX, y: y))
                context.stroke(hLine, with: .color(gridColor), lineWidth: 0.5)
            }

            context.stroke(
                Path(roundedRect: plotRect, cornerRadius: 4),
                with: .color(Color(nsColor: .separatorColor)),
                lineWidth: 1
            )

            // Dead zone shaded region
            let dzWidth = plotRect.width * CGFloat(min(max(deadZone, 0), 1))
            let dzRect = CGRect(x: plotRect.minX, y: plotRect.minY, width: dzWidth, height: plotRect.height)
            context.fill(Path(dzRect), with: .color(Color.orange.opacity(0.12)))

            // Diagonal linear reference line
            var linearPath = Path()
            linearPath.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
            linearPath.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.minY))
            context.stroke(
                linearPath,
                with: .color(Color.secondary.opacity(0.3)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            // Active exponential curve
            var curvePath = Path()
            let steps = 60
            for i in 0...steps {
                let xNorm = Double(i) / Double(steps)
                let yNorm = curveOutput(for: xNorm)
                let pt = CGPoint(
                    x: plotRect.minX + plotRect.width * CGFloat(xNorm),
                    y: plotRect.maxY - plotRect.height * CGFloat(yNorm)
                )
                if i == 0 {
                    curvePath.move(to: pt)
                } else {
                    curvePath.addLine(to: pt)
                }
            }
            context.stroke(curvePath, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            // Live stick deflection marker
            let clamped = min(max(liveInput, 0), 1)
            let outY = curveOutput(for: clamped)
            let dotCenter = CGPoint(
                x: plotRect.minX + plotRect.width * CGFloat(clamped),
                y: plotRect.maxY - plotRect.height * CGFloat(outY)
            )
            let dotRect = CGRect(x: dotCenter.x - 4.5, y: dotCenter.y - 4.5, width: 9, height: 9)
            context.fill(Path(ellipseIn: dotRect), with: .color(clamped >= deadZone ? .accentColor : .orange))
        }
        .accessibilityLabel("Response curve graph with dead zone at \(Int(deadZone * 100)) percent and exponent \(String(format: "%.1f", exponent))")
    }

    private func curveOutput(for input: Double) -> Double {
        guard input >= deadZone else { return 0 }
        return pow(input, exponent)
    }
}
