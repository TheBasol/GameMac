import SwiftUI

@available(macOS 13.0, *)
struct StatusBar: View {
    @ObservedObject var viewModel: GameMacViewModel
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Connection status and info
            HStack(spacing: 10) {
                Circle()
                    .fill(viewModel.gamepadState.isConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                    .shadow(color: viewModel.gamepadState.isConnected ? .green.opacity(0.8) : .clear, radius: 4)
                
                if viewModel.connectedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Device Detected")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Plug in your gamepad")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Picker(selection: Binding(
                            get: { viewModel.activeDevice },
                            set: { newDevice in
                                if let dev = newDevice {
                                    viewModel.selectActiveDevice(dev)
                                }
                            }
                        ), label: EmptyView()) {
                            ForEach(viewModel.connectedDevices) { device in
                                Text(device.name).tag(device as DeviceInfo?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        
                        if let active = viewModel.activeDevice {
                            Text(String(format: "VID: %04X • PID: %04X", active.vendorID, active.productID))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Capture native controllers toggle
            Toggle("Capture Native", isOn: $viewModel.captureNativeControllers)
                .toggleStyle(.checkbox)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .help("Include Xbox, PlayStation, Switch and other native macOS controllers")
            
            // Driver controls
            HStack(spacing: 12) {
                // Active status label
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.isDriverRunning ? Color.blue : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(viewModel.isDriverRunning ? "ACTIVE" : "STOPPED")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.isDriverRunning ? .blue : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(viewModel.isDriverRunning ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                )
                
                // Toggle Button
                Button(action: {
                    if viewModel.isDriverRunning {
                        viewModel.stopDriver()
                    } else {
                        viewModel.startDriver()
                    }
                }) {
                    Text(viewModel.isDriverRunning ? "Stop Service" : "Start Service")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: viewModel.isDriverRunning ? [.red.opacity(0.8), .red] : [.blue.opacity(0.8), .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(6)
                        .shadow(color: (viewModel.isDriverRunning ? Color.red : Color.blue).opacity(0.3), radius: 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Restart action
                Button(action: {
                    viewModel.restartDriver()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Restart mapping daemon")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
