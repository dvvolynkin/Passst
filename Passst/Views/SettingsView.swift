import AppKit
@preconcurrency import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @AppStorage(PreferencesKey.appearance)
    private var appearanceRawValue = AppAppearance.system.rawValue
    @State private var excludedBundleIdentifiers: [String]

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var confirmationPresented = false
    @State private var localStatus: SettingsStatus?
    @AppStorage(PreferencesKey.copySoundEnabled)
    private var copySoundEnabled = true

    init(model: AppModel) {
        self.model = model
        _excludedBundleIdentifiers = State(
            initialValue: UserDefaults.standard.stringArray(
                forKey: PreferencesKey.excludedBundleIdentifiers
            ) ?? []
        )
    }

    var body: some View {
        Form {
            Section("General") {
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open Passst")
                        Text("Global keyboard shortcut")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 24)
                    KeyboardShortcuts.Recorder(for: .togglePassst)
                        .frame(width: 156, alignment: .trailing)
                }
                .padding(.vertical, 3)

                Toggle("Launch Passst at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }

                Picker("Appearance", selection: $appearanceRawValue) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                .onChange(of: appearanceRawValue) { _, value in
                    model.setAppearance(AppAppearance(rawValue: value) ?? .system)
                }

                Toggle(
                    "Pause clipboard history",
                    isOn: Binding(
                        get: { model.monitorPaused },
                        set: { _ in model.toggleMonitoring() }
                    )
                )

                Toggle("Play sound when copying", isOn: $copySoundEnabled)
                    .onChange(of: copySoundEnabled) { _, enabled in
                        if enabled {
                            CopyFeedbackPlayer.shared.play()
                        }
                    }
                    .help("Play feedback after Passst copies or pastes a selection")
            }

            Section("Direct Paste") {
                LabeledContent("Accessibility") {
                    HStack(spacing: 9) {
                        Label(
                            model.accessibilityGranted
                                ? "Allowed"
                                : "Not allowed",
                            systemImage: model.accessibilityGranted
                                ? "checkmark.circle.fill"
                                : "exclamationmark.circle.fill"
                        )
                        .foregroundStyle(
                            model.accessibilityGranted
                                ? Color.green
                                : Color.orange
                        )

                        if !model.accessibilityGranted {
                            Button("Open Settings") {
                                let granted = model.requestAccessibilityAccess()
                                localStatus = SettingsStatus(
                                    message: granted
                                        ? "Accessibility access is enabled."
                                        : "Enable Passst in Privacy & Security → Accessibility. This screen updates automatically.",
                                    isError: false
                                )
                            }
                        }
                    }
                }

                if !model.accessibilityGranted {
                    HStack(spacing: 12) {
                        Image(nsImage: applicationIcon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 40, height: 40)
                            .onDrag {
                                NSItemProvider(contentsOf: Bundle.main.bundleURL)
                                    ?? NSItemProvider()
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Passst")
                                .font(.system(size: 13, weight: .semibold))
                            Text("You can drag this icon into the Accessibility applications list.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }

                Text(
                    "Accessibility is requested only when you first use Enter to paste. "
                    + "Control+C and Command+C work without it."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Excluded Applications") {
                if excludedBundleIdentifiers.isEmpty {
                    Text("Clipboard changes from every application are recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(excludedBundleIdentifiers, id: \.self) { identifier in
                        HStack {
                            if let icon = AppIconProvider.shared.icon(bundleIdentifier: identifier) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 22, height: 22)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(applicationName(for: identifier))
                                Text(identifier)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                excludedBundleIdentifiers.removeAll { $0 == identifier }
                                saveExclusions()
                                localStatus = SettingsStatus(
                                    message: "Removed \(applicationName(for: identifier)) from exclusions.",
                                    isError: false
                                )
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove exclusion")
                        }
                    }
                }

                Button("Add Application…") {
                    chooseExcludedApplication()
                }
            }

            Section("Storage") {
                LabeledContent("History size") {
                    Text(ByteCountFormatter.string(
                        fromByteCount: model.storageSize,
                        countStyle: .file
                    ))
                    .monospacedDigit()
                }

                Button("Refresh Size") {
                    model.refreshStorageSize()
                    localStatus = SettingsStatus(
                        message: "Storage size refreshed.",
                        isError: false
                    )
                }

                Button("Clear All History…", role: .destructive) {
                    confirmationPresented = true
                }
            }

            if let localStatus {
                Section {
                    Label(
                        localStatus.message,
                        systemImage: localStatus.isError
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .foregroundStyle(localStatus.isError ? Color.red : Color.green)
                    .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
        .frame(minWidth: 560, minHeight: 520)
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $confirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                model.clearHistory()
                localStatus = SettingsStatus(message: "History cleared.", isError: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes all saved clipboard items and previews. It cannot be undone.")
        }
        .onAppear {
            model.refreshStorageSize()
            model.refreshAccessibilityStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            model.refreshAccessibilityStatus()
        }
        .task {
            while !Task.isCancelled {
                model.refreshAccessibilityStatus()
                do {
                    try await Task.sleep(for: .milliseconds(700))
                } catch {
                    return
                }
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            localStatus = SettingsStatus(
                message: enabled
                    ? "Passst will launch at login."
                    : "Passst will no longer launch at login.",
                isError: false
            )
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            localStatus = SettingsStatus(message: error.localizedDescription, isError: true)
        }
    }

    private func chooseExcludedApplication() {
        let panel = NSOpenPanel()
        panel.title = "Exclude an Application"
        panel.prompt = "Exclude"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier
        else {
            return
        }
        if !excludedBundleIdentifiers.contains(identifier) {
            excludedBundleIdentifiers.append(identifier)
            saveExclusions()
        }
        localStatus = SettingsStatus(
            message: "\(bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent) excluded.",
            isError: false
        )
    }

    private func applicationName(for bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return bundleIdentifier
        }
        return Bundle(url: url)?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
    }

    private func saveExclusions() {
        UserDefaults.standard.set(
            excludedBundleIdentifiers,
            forKey: PreferencesKey.excludedBundleIdentifiers
        )
    }

    private var applicationIcon: NSImage {
        NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}

private struct SettingsStatus {
    let message: String
    let isError: Bool
}
