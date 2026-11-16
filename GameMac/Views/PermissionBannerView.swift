import SwiftUI
import AppKit

@available(macOS 13.0, *)
struct PermissionBannerView: View {
    @ObservedObject var viewModel: GameMacViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle)
                    .font(.subheadline.weight(.semibold))
                Text(bannerMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if !viewModel.hasAccessibilityPermission {
                    Button("Grant Accessibility…") {
                        PermissionChecker.shared.openAccessibilitySettings()
                    }
                    .controlSize(.small)
                }

                if !viewModel.hasInputMonitoringPermission {
                    Button("Grant Input Monitoring…") {
                        PermissionChecker.shared.openInputMonitoringSettings()
                    }
                    .controlSize(.small)
                }

                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Text("Diagnostics…")
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                } else {
                    Button("Diagnostics…") {
                        NSApp.activate(ignoringOtherApps: true)
                        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        }
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.30), lineWidth: 1)
        )
    }

    private var bannerTitle: String {
        if !viewModel.hasAccessibilityPermission && !viewModel.hasInputMonitoringPermission {
            return "macOS Permissions Required"
        } else if !viewModel.hasAccessibilityPermission {
            return "Accessibility Permission Required"
        } else {
            return "Input Monitoring Permission Required"
        }
    }

    private var bannerMessage: String {
        if !viewModel.hasAccessibilityPermission && !viewModel.hasInputMonitoringPermission {
            return "GameMac needs Accessibility to send keystrokes and Input Monitoring to read USB controllers."
        } else if !viewModel.hasAccessibilityPermission {
            return "Controller inputs are being read, but keystrokes and mouse movement cannot be injected yet."
        } else {
            return "macOS is blocking direct USB/HID controller access until Input Monitoring is enabled."
        }
    }
}
