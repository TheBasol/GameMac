import SwiftUI
import AppKit

@available(macOS 13.0, *)
struct ContentView: View {
    @ObservedObject var viewModel: GameMacViewModel

    @State private var inspectorTab: InspectorTab = .mappings
    @State private var searchText = ""

    // Profile Dialog States
    @State private var newProfileName = ""
    @State private var profileNameError: String? = nil
    @State private var profileToRename: MappingProfile? = nil
    @State private var renameProfileText = ""
    @State private var profileToDelete: MappingProfile? = nil

    enum InspectorTab: String, CaseIterable {
        case mappings = "Mappings"
        case sticksAndMouse = "Sticks & Mouse"
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 225, max: 270)
        } detail: {
            detailContent
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter controls")
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty && inspectorTab != .mappings {
                inspectorTab = .mappings
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if viewModel.connectedDevices.count > 1 {
                    Picker("Controller", selection: Binding(
                        get: { viewModel.activeDevice },
                        set: { newDev in
                            if let dev = newDev {
                                viewModel.selectActiveDevice(dev)
                            }
                        }
                    )) {
                        ForEach(viewModel.connectedDevices) { device in
                            Text(device.name).tag(device as DeviceInfo?)
                        }
                    }
                    .frame(maxWidth: 190)
                }

                Picker("Mouse Mode", selection: Binding(
                    get: { viewModel.isFpsMode },
                    set: { viewModel.setMouseMode(isFpsMode: $0) }
                )) {
                    Text("Desktop").tag(false)
                    Text("FPS").tag(true)
                }
                .pickerStyle(.segmented)
                .help("Desktop moves the macOS cursor; FPS sends raw relative camera deltas")

                Button {
                    viewModel.toggleDriver()
                } label: {
                    Label(
                        viewModel.isDriverRunning ? "Active" : "Paused",
                        systemImage: viewModel.isDriverRunning ? "pause.fill" : "play.fill"
                    )
                }
                .tint(viewModel.isDriverRunning ? .accentColor : .orange)
                .help(viewModel.isDriverRunning ? "Pause controller mapping" : "Resume controller mapping")

                Button {
                    viewModel.showingHardwareSetupSheet = true
                } label: {
                    Label("Hardware Setup", systemImage: "wrench.and.screwdriver")
                }
                .disabled(viewModel.activeDevice == nil)
                .help("Configure physical controller layout and axis calibration")
            }
        }
        .sheet(isPresented: $viewModel.showingHardwareSetupSheet) {
            HardwareSetupSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingNewProfileSheet) {
            profileNameSheet(
                title: "New Profile",
                actionTitle: "Create",
                nameBinding: $newProfileName,
                onSubmit: {
                    if viewModel.createProfile(name: newProfileName) {
                        viewModel.showingNewProfileSheet = false
                    } else {
                        profileNameError = "Enter a unique, non-empty profile name."
                    }
                },
                onCancel: {
                    viewModel.showingNewProfileSheet = false
                }
            )
        }
        .sheet(item: $profileToRename) { profile in
            profileNameSheet(
                title: "Rename Profile",
                actionTitle: "Rename",
                nameBinding: $renameProfileText,
                onSubmit: {
                    if viewModel.renameProfile(profile, to: renameProfileText) {
                        profileToRename = nil
                    } else {
                        profileNameError = "Enter a unique, non-empty profile name."
                    }
                },
                onCancel: {
                    profileToRename = nil
                }
            )
        }
        .alert(
            "Delete \"\(profileToDelete?.profileName ?? "")\"?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    viewModel.deleteProfile(profile)
                }
                profileToDelete = nil
            }
        } message: {
            Text("This mapping profile will be permanently removed from disk.")
        }
        .onAppear {
            viewModel.reloadProfiles()
            viewModel.checkPermissions()
        }
        .frame(minWidth: 860, minHeight: 560)
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: Binding<String?>(
            get: { viewModel.activeProfile.profileName },
            set: { selectedName in
                if let name = selectedName,
                   let match = viewModel.profiles.first(where: { $0.profileName == name }) {
                    viewModel.selectProfile(match)
                }
            }
        )) {
            Section("Profiles") {
                ForEach(viewModel.profiles, id: \.profileName) { profile in
                    HStack(spacing: 8) {
                        Image(systemName: profile.isFpsMode ? "scope" : "gamecontroller")
                            .foregroundColor(profile.profileName == viewModel.activeProfile.profileName ? .accentColor : .secondary)
                            .frame(width: 16)

                        Text(profile.profileName)
                            .lineLimit(1)

                        Spacer()

                        if profile.isFpsMode {
                            Text("FPS")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(profile.profileName)
                    .contextMenu {
                        Button("Rename…") {
                            renameProfileText = profile.profileName
                            profileNameError = nil
                            profileToRename = profile
                        }

                        Button("Duplicate") {
                            viewModel.duplicateProfile(profile)
                        }

                        Divider()

                        Button("Delete…", role: .destructive) {
                            profileToDelete = profile
                        }
                        .disabled(viewModel.profiles.count <= 1)
                    }
                }
            }

            Section("Controllers") {
                if viewModel.connectedDevices.isEmpty {
                    Label("No device connected", systemImage: "cable.connector.slash")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.connectedDevices) { device in
                        Button {
                            viewModel.selectActiveDevice(device)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(viewModel.activeDevice?.id == device.id ? Color.green : Color.secondary.opacity(0.4))
                                    .frame(width: 7, height: 7)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(device.name)
                                        .font(.callout)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(String(format: "%04X:%04X", device.vendorID, device.productID))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !viewModel.hasAllPermissions {
                Section("Attention") {
                    if #available(macOS 14.0, *) {
                        SettingsLink {
                            Label("Permissions Missing", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    } else {
                        Button {
                            NSApp.activate(ignoringOtherApps: true)
                            if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                            }
                        } label: {
                            Label("Permissions Missing", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 8) {
                    Button {
                        newProfileName = ""
                        profileNameError = nil
                        viewModel.showingNewProfileSheet = true
                    } label: {
                        Label("New Profile", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)

                    Spacer()

                    Menu {
                        Button("Rename Current…") {
                            renameProfileText = viewModel.activeProfile.profileName
                            profileNameError = nil
                            profileToRename = viewModel.activeProfile
                        }
                        Button("Duplicate Current") {
                            viewModel.duplicateProfile(viewModel.activeProfile)
                        }
                        Divider()
                        Button("Delete Current…", role: .destructive) {
                            profileToDelete = viewModel.activeProfile
                        }
                        .disabled(viewModel.profiles.count <= 1)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 22)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.bar)
        }
    }

    // MARK: - Detail Workbench

    private var detailContent: some View {
        VStack(spacing: 12) {
            if !viewModel.hasAllPermissions {
                PermissionBannerView(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            HSplitView {
                // Left Pane: Interactive Controller Visualizer
                VStack(spacing: 0) {
                    ControllerVisualizer(
                        viewModel: viewModel,
                        onOpenHardwareSetup: {
                            viewModel.showingHardwareSetupSheet = true
                        },
                        onSwitchToSticksTab: {
                            inspectorTab = .sticksAndMouse
                        }
                    )
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, viewModel.hasAllPermissions ? 16 : 4)
                .frame(minWidth: 360, idealWidth: 430)

                // Right Pane: Segmented Inspector (Mappings / Sticks & Mouse)
                VStack(spacing: 0) {
                    HStack {
                        Picker("Inspector", selection: $inspectorTab) {
                            ForEach(InspectorTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                    .padding(12)

                    Divider()

                    if inspectorTab == .mappings {
                        MappingInspectorView(
                            viewModel: viewModel,
                            searchText: searchText,
                            onSwitchToSticksTab: {
                                inspectorTab = .sticksAndMouse
                            }
                        )
                    } else {
                        StickAndMouseView(viewModel: viewModel)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .padding(.vertical, viewModel.hasAllPermissions ? 16 : 4)
                .frame(minWidth: 290, idealWidth: 340)
            }
            .padding(.bottom, 12)
        }
        .navigationTitle(viewModel.activeProfile.profileName)
        .navigationSubtitle(
            viewModel.activeDevice?.name ?? "No controller connected"
        )
    }

    // MARK: - Profile Name Sheet

    private func profileNameSheet(
        title: String,
        actionTitle: String,
        nameBinding: Binding<String>,
        onSubmit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            TextField("Profile name", text: nameBinding)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onSubmit()
                }

            if let error = profileNameError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button(actionTitle, action: onSubmit)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(nameBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 300)
    }
}

extension MappingProfile: Identifiable {
    public var id: String { profileName }
}
