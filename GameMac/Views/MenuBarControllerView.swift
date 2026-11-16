import SwiftUI
import AppKit

@available(macOS 13.0, *)
struct MenuBarControllerView: View {
    @ObservedObject var viewModel: GameMacViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            // Connection & Permission Status
            if !viewModel.hasAllPermissions {
                Text("Permissions Needed — Open Studio")
            } else if let active = viewModel.activeDevice {
                Text("\(active.name) • \(viewModel.isDriverRunning ? "Active" : "Paused")")
            } else {
                Text("No Controller Connected")
            }

            Divider()

            Button(viewModel.isDriverRunning ? "Pause Mapping" : "Resume Mapping") {
                viewModel.toggleDriver()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            // Active Profile Switcher
            Menu("Active Profile: \(viewModel.activeProfile.profileName)") {
                ForEach(viewModel.profiles, id: \.profileName) { profile in
                    Button {
                        viewModel.selectProfile(profile)
                    } label: {
                        HStack {
                            Text(profile.profileName)
                            if profile.profileName == viewModel.activeProfile.profileName {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            // Mouse Emulation Mode
            Picker("Mouse Mode", selection: Binding(
                get: { viewModel.isFpsMode },
                set: { viewModel.setMouseMode(isFpsMode: $0) }
            )) {
                Text("Desktop Cursor").tag(false)
                Text("FPS Raw Delta").tag(true)
            }

            Divider()

            Button("Open GameMac Studio…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }

            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Settings…")
                }
            } else {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            Divider()

            Button("Quit GameMac") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
