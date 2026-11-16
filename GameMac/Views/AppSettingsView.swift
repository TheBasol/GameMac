import SwiftUI

@available(macOS 13.0, *)
struct AppSettingsView: View {
    @ObservedObject var viewModel: GameMacViewModel
    @State private var selectedTab: SettingsTab = .general
    @State private var confirmingRestoreDefaults = false

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case permissions = "Permissions"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "hand.raised")
                }
                .tag(SettingsTab.permissions)
        }
        .frame(width: 500, height: 390)
        .onAppear {
            viewModel.checkPermissions()
        }
    }

    private var generalTab: some View {
        Form {
            Section("Controller Detection") {
                Toggle("Capture Native macOS Controllers", isOn: $viewModel.captureNativeControllers)
                Text("Includes Xbox, PlayStation, Nintendo Switch, and Apple-supported controllers that macOS normally handles natively. Toggling restarts device discovery.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Profiles") {
                LabeledContent("Profiles Folder") {
                    Button("Show in Finder") {
                        viewModel.revealProfilesFolder()
                    }
                }

                LabeledContent("Built-In Presets") {
                    Button("Restore Defaults…") {
                        confirmingRestoreDefaults = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .alert("Restore Default Profiles?", isPresented: $confirmingRestoreDefaults) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                viewModel.restoreDefaultProfiles()
            }
        } message: {
            Text("This resets FPS Shooter, Platformer, and RPG to their built-in configurations. Custom profiles with other names are preserved.")
        }
    }

    private var permissionsTab: some View {
        Form {
            Section("Required Authorizations") {
                permissionRow(
                    title: "Accessibility",
                    subtitle: "Synthesize keyboard keys and mouse movement",
                    isGranted: viewModel.hasAccessibilityPermission,
                    action: { PermissionChecker.shared.openAccessibilitySettings() }
                )

                permissionRow(
                    title: "Input Monitoring",
                    subtitle: "Read low-level HID and USB gamepads",
                    isGranted: viewModel.hasInputMonitoringPermission,
                    action: { PermissionChecker.shared.openInputMonitoringSettings() }
                )
            }

            Section("Event Injection Diagnostics") {
                LabeledContent("System Tap Status") {
                    HStack(spacing: 8) {
                        Button("Verify Injection") {
                            viewModel.performTestInjection()
                        }
                        Button("Refresh") {
                            viewModel.checkPermissions()
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: diagnosticIcon)
                        .foregroundColor(diagnosticColor)
                    Text(viewModel.testInjectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                DisclosureGroup("Permissions stopped working after updating or rebuilding?") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("If macOS caches an outdated code signature after recompiling GameMac:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("1. Open System Settings → Privacy & Security → Accessibility and Input Monitoring.")
                        Text("2. Select GameMac in each list and click the minus (−) button to remove it.")
                        Text("3. Re-add GameMac.app or toggle it back on.")
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func permissionRow(
        title: String,
        subtitle: String,
        isGranted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        LabeledContent {
            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.callout)
            } else {
                Button("Open Settings…", action: action)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var diagnosticIcon: String {
        switch viewModel.testInjectionSucceeded {
        case .some(true): return "checkmark.circle.fill"
        case .some(false): return "xmark.octagon.fill"
        case .none: return "info.circle"
        }
    }

    private var diagnosticColor: Color {
        switch viewModel.testInjectionSucceeded {
        case .some(true): return .green
        case .some(false): return .red
        case .none: return .secondary
        }
    }
}
