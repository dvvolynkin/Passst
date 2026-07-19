import AppKit
@preconcurrency import KeyboardShortcuts
import SwiftUI

@main
@MainActor
struct PassstApp: App {
    @NSApplicationDelegateAdaptor(PassstApplicationDelegate.self)
    private var applicationDelegate
    @State private var model: AppModel

    init() {
        do {
            let model = try AppModel()
            _model = State(initialValue: model)
            PassstApplicationDelegate.model = model
        } catch {
            fatalError("Passst could not start: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            Image(nsImage: PassstBrandAssets.menuBarMark)
                .renderingMode(.template)
                .opacity(model.monitorPaused ? 0.45 : 1)
                .accessibilityLabel(
                    model.monitorPaused ? "Passst, history paused" : "Passst"
                )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 560, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Passst") {
                    let version = Bundle.main.object(
                        forInfoDictionaryKey: "CFBundleShortVersionString"
                    ) as? String ?? "0.1.2"
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "Passst",
                            .applicationVersion: version
                        ]
                    )
                }
            }
        }
    }
}

@MainActor
private final class PassstApplicationDelegate: NSObject, NSApplicationDelegate {
    static weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.model?.registerGlobalShortcut()
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else {
            return
        }
        Task { @MainActor in
            await Task.yield()
            Self.model?.presentPanel()
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        Self.model?.presentPanel()
        return true
    }
}

private struct MenuBarContentView: View {
    let model: AppModel

    var body: some View {
        Button("Show Passst") {
            model.togglePanel()
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])

        Divider()

        Button(model.monitorPaused ? "Resume Clipboard History" : "Pause Clipboard History") {
            model.toggleMonitoring()
        }

        Button("Settings…") {
            model.showSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Passst") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
