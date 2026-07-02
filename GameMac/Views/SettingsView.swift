import SwiftUI

@available(macOS 13.0, *)
struct SettingsView: View {
    @ObservedObject var viewModel: GameMacViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Text("ENGINE & VELOCITY SETTINGS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        // Mode selector
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mouse Emulation Mode")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 2) {
                                Button(action: {
                                    viewModel.isFpsMode = true
                                    viewModel.restartDriver()
                                }) {
                                    Text("FPS Mode")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(viewModel.isFpsMode ? .black : .white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(viewModel.isFpsMode ? Color.cyan : Color.clear)
                                        .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    viewModel.isFpsMode = false
                                    viewModel.restartDriver()
                                }) {
                                    Text("Desktop Mode")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(!viewModel.isFpsMode ? .black : .white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(!viewModel.isFpsMode ? Color.cyan : Color.clear)
                                        .cornerRadius(5)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(2)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(7)
                            
                            Text(viewModel.isFpsMode ? "Delivers raw delta mouse inputs (cursor is disassociated). Essential for FPS and 3D camera control." : "Standard mouse emulation warped to screen boundaries. Good for standard system or 2D play.")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .padding(.top, 2)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.05))
                        
                        // Dead Zone
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Stick Dead Zone")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%d%%", Int(viewModel.deadZone * 100)))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            
                            Slider(value: $viewModel.deadZone, in: 0.05...0.35, step: 0.01) {
                                Text("")
                            }
                            .onChange(of: viewModel.deadZone) { _ in
                                viewModel.saveCurrentProfile()
                            }
                        }
                        
                        // Mouse Sensitivity
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Mouse Sensitivity")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.1fx", viewModel.mouseSensitivity))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            
                            Slider(value: $viewModel.mouseSensitivity, in: 0.5...3.5, step: 0.1) {
                                Text("")
                            }
                            .onChange(of: viewModel.mouseSensitivity) { _ in
                                viewModel.saveCurrentProfile()
                            }
                        }
                        
                        // Response Exponent
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Stick Response Exponent")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.1f", viewModel.mouseExponent))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                            
                            Slider(value: $viewModel.mouseExponent, in: 1.0...2.5, step: 0.1) {
                                Text("")
                            }
                            .onChange(of: viewModel.mouseExponent) { _ in
                                viewModel.saveCurrentProfile()
                            }
                            
                            Text("Non-linear response curves give finer micro-adjustment near center sticks and faster rotation speed at outer edges.")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.02))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                
                // Calibration section
                if let active = viewModel.activeDevice {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MANUAL AXIS CALIBRATION (OVERRIDE)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(1.2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Override the logical minimum and maximum values for stick/trigger axes in case the controller's descriptor lies.")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                            .padding(.bottom, 4)
                        
                        let layout = LayoutManager.shared.loadLayout(for: active)
                        
                        VStack(spacing: 8) {
                            ForEach(layout.axisMap.sorted(by: { $0.key < $1.key }), id: \.key) { usage, axisName in
                                AxisCalibrationView(layoutKey: layout.layoutKey, usage: usage, name: axisName)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
                }
            }
        }
    }
}

@available(macOS 13.0, *)
struct AxisCalibrationView: View {
    let layoutKey: String
    let usage: Int
    let name: String
    
    @State private var minVal: Int = 0
    @State private var maxVal: Int = 255
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prettifyAxisName(name))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text(String(format: "Usage: 0x%02X (%d)", usage, usage))
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Min")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    TextField("Min", value: $minVal, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                        .onSubmit {
                            save()
                        }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Max")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    TextField("Max", value: $maxVal, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 60)
                        .onSubmit {
                            save()
                        }
                }
                
                Button("Save") {
                    save()
                }
                .font(.system(size: 10, weight: .bold))
                
                Button("Reset") {
                    CalibrationManager.shared.removeCalibration(layoutKey: layoutKey, usage: usage)
                    resetToDefault()
                }
                .font(.system(size: 10))
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadCurrent()
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
    
    private func resetToDefault() {
        minVal = 0
        maxVal = 255
    }
    
    private func save() {
        CalibrationManager.shared.saveCalibration(layoutKey: layoutKey, usage: usage, min: minVal, max: maxVal)
    }
}
