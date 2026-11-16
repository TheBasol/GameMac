import SwiftUI

@main
@available(macOS 13.0, *)
struct GameMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = GameMacViewModel.shared

    var body: some Scene {
        Window("GameMac", id: "main") {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(width: 1000, height: 640)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Profile…") {
                    viewModel.showingNewProfileSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Controller") {
                Button(viewModel.isDriverRunning ? "Pause Mapping" : "Resume Mapping") {
                    viewModel.toggleDriver()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])

                Button(viewModel.isFpsMode ? "Switch to Desktop Cursor Mode" : "Switch to FPS Raw Delta Mode") {
                    viewModel.setMouseMode(isFpsMode: !viewModel.isFpsMode)
                }
                .keyboardShortcut("m", modifiers: [.command, .option])

                Divider()

                Button("Hardware Setup & Calibration…") {
                    viewModel.showingHardwareSetupSheet = true
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(viewModel.activeDevice == nil)
            }
        }

        Settings {
            AppSettingsView(viewModel: viewModel)
        }

        MenuBarExtra(
            "GameMac",
            systemImage: viewModel.isDriverRunning ? "gamecontroller.fill" : "gamecontroller"
        ) {
            MenuBarControllerView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.menu)
    }
}
