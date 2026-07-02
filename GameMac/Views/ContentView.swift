import SwiftUI

@available(macOS 13.0, *)
struct ContentView: View {
    @StateObject private var viewModel = GameMacViewModel.shared
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case mappings = "Mappings"
        case settings = "Settings"
        case permissions = "Permissions"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .dashboard: return "gamecontroller.fill"
            case .mappings: return "keyboard.fill"
            case .settings: return "slider.horizontal.3"
            case .permissions: return "shield.righthalf.filled"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            VStack(alignment: .leading, spacing: 14) {
                // Application Title
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                    
                    Text("GameMac")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.5)
                }
                .padding(.horizontal, 8)
                .padding(.top, 14)
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Navigation Links
                VStack(spacing: 4) {
                    ForEach(Tab.allCases) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12))
                                    .frame(width: 16, height: 16)
                                
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.7))
                            .background(selectedTab == tab ? Color.cyan : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                // Connected Devices List in Sidebar
                if !viewModel.connectedDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONNECTED DEVICES")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                            .tracking(1.0)
                        
                        ForEach(viewModel.connectedDevices) { device in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.activeDevice?.id == device.id ? Color.cyan : Color.gray)
                                    .frame(width: 5, height: 5)
                                Text(device.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(viewModel.activeDevice?.id == device.id ? .white : .gray)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 14)
                }
                
                // Footer
                Text("Version 1.0.0")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
            }
            .frame(width: 160)
            .padding(.horizontal, 10)
            .background(Color(white: 0.04))
            
            // Vertical Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)
            
            // Main Content Area
            VStack(spacing: 0) {
                // Persistent Status Bar at top
                StatusBar(viewModel: viewModel)
                    .padding(14)
                
                // Active pane view selector
                ZStack {
                    switch selectedTab {
                    case .dashboard:
                        VStack(spacing: 16) {
                            ProfileSelectorView(viewModel: viewModel)
                            ControllerVisualizer(viewModel: viewModel)
                            Spacer()
                        }
                        .transition(.opacity)
                        
                    case .mappings:
                        MappingEditorView(viewModel: viewModel)
                            .transition(.opacity)
                        
                    case .settings:
                        SettingsView(viewModel: viewModel)
                            .transition(.opacity)
                        
                    case .permissions:
                        PermissionView(viewModel: viewModel)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(white: 0.08))
        }
        .frame(minWidth: 800, minHeight: 520)
        .preferredColorScheme(.dark)
    }
}
