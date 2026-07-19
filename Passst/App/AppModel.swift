import AppKit
import Foundation
@preconcurrency import KeyboardShortcuts
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    private(set) var records: [ClipboardRecord] = []
    private(set) var isLoading = false
    private(set) var hasMore = false
    private(set) var monitorPaused: Bool
    private(set) var storageSize: Int64 = 0
    private(set) var accessibilityGranted = false
    private(set) var mediaRefreshGeneration = 0

    var searchQuery = "" {
        didSet {
            guard oldValue != searchQuery else { return }
            if !searchQuery.isEmpty {
                isSearchFocused = true
            }
            scheduleSearch()
        }
    }
    var isSearchFocused = false
    var previewedID: UUID?
    var previewPayload: ClipboardPayload?
    var notice: PanelNotice?
    var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    let selection = SelectionState()
    let directPasteService: DirectPasteService

    private let repository: HistoryRepository
    private let codec: PasteboardCodec
    private let payloadBuilder: SelectionPayloadBuilder
    private let accessibilityService: AccessibilityService
    private let isUITesting: Bool
    @ObservationIgnored
    private lazy var clipboardMonitor = ClipboardMonitor(
        codec: codec,
        captureHandler: { [weak self] payload, sourceApplication in
            self?.capture(payload, sourceApplication: sourceApplication)
        },
        errorHandler: { [weak self] error in
            self?.show(error: error)
        }
    )
    @ObservationIgnored
    private lazy var panelController = PanelController(model: self)
    private var settingsController: NSWindowController?
    private var searchTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var activeLoadGeneration = 0
    private var didStart = false
    private var didRegisterGlobalShortcut = false
    @ObservationIgnored
    private var workspaceObserverTokens: [NSObjectProtocol] = []

    init(rootURL: URL? = nil) throws {
        let arguments = ProcessInfo.processInfo.arguments
        isUITesting = arguments.contains("--ui-testing")
        let effectiveRootURL: URL?
        if let rootURL {
            effectiveRootURL = rootURL
        } else if isUITesting {
            effectiveRootURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("app.passst.ui-tests", isDirectory: true)
        } else {
            effectiveRootURL = nil
        }

        repository = try HistoryRepository(rootURL: effectiveRootURL)
        codec = PasteboardCodec()
        payloadBuilder = SelectionPayloadBuilder(repository: repository)
        accessibilityService = AccessibilityService()
        directPasteService = DirectPasteService(accessibility: accessibilityService)
        accessibilityGranted = accessibilityService.isTrusted
        monitorPaused = UserDefaults.standard.bool(forKey: PreferencesKey.monitorPaused)

        applyStoredAppearance()
        start()
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        restoreRequestedShortcutIfNeeded()
        installWorkspaceObservers()
        clipboardMonitor.start()
        if isUITesting {
            installUITestFixtures()
        } else {
            reloadHistory(reset: true, animated: false)
            refreshStorageSize()

            if ProcessInfo.processInfo.arguments.contains("--show-panel") {
                Task {
                    await Task.yield()
                    presentPanel()
                }
            }
        }
    }

    func registerGlobalShortcut() {
        guard !didRegisterGlobalShortcut else { return }
        didRegisterGlobalShortcut = true
        KeyboardShortcuts.onKeyDown(for: .togglePassst) { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
    }

    func togglePanel() {
        if panelController.shouldPresentOnToggle {
            presentPanel()
        } else {
            panelController.close()
        }
    }

    func presentPanel() {
        guard !panelController.isPresented else { return }
        selection.reset(records: records, preservingSelection: false)
        panelController.present()
        reloadHistory(reset: true, animated: false)
    }

    func closePanel() {
        previewedID = nil
        previewPayload = nil
        isSearchFocused = false
        panelController.close()
    }

    func toggleMonitoring() {
        clipboardMonitor.togglePaused()
        monitorPaused = clipboardMonitor.isPaused
        showNotice(
            monitorPaused ? "Clipboard history paused" : "Clipboard history resumed",
            symbol: monitorPaused ? "pause.fill" : "play.fill"
        )
    }

    func togglePreview() {
        if previewedID != nil {
            previewedID = nil
            previewPayload = nil
            return
        }
        guard let focusedID = selection.focusedID,
              let record = records.first(where: { $0.id == focusedID })
        else {
            return
        }
        previewedID = focusedID
        previewPayload = nil
        Task {
            do {
                let payload = try await repository.payload(for: record)
                guard previewedID == focusedID else { return }
                previewPayload = payload
            } catch {
                show(error: error)
                previewedID = nil
            }
        }
    }

    func movePreview(delta: Int) {
        guard previewedID != nil else { return }
        selection.move(delta: delta, extending: false, records: records)
        previewedID = nil
        previewPayload = nil
        togglePreview()
    }

    func handle(_ command: PanelKeyCommand) {
        switch command {
        case let .move(delta, extending):
            if previewedID != nil {
                movePreview(delta: delta)
            } else {
                selection.move(delta: delta, extending: extending, records: records)
            }
        case .copy:
            copySelection()
        case let .paste(plainText):
            pasteSelection(plainText: plainText)
        case .preview:
            togglePreview()
        case .escape:
            if previewedID != nil {
                previewedID = nil
                previewPayload = nil
            } else if isSearchFocused || !searchQuery.isEmpty {
                searchQuery = ""
                isSearchFocused = false
            } else {
                closePanel()
            }
        case .focusSearch:
            isSearchFocused = true
        case .selectAll:
            selection.selectAll(records: records)
        case .delete:
            deleteSelection()
        }
    }

    func copySelection() {
        performSelectionAction(plainText: false, directPaste: false)
    }

    func pasteSelection(plainText: Bool) {
        performSelectionAction(plainText: plainText, directPaste: true)
    }

    func loadMoreIfNeeded(visibleRecord: ClipboardRecord) {
        guard hasMore, !isLoading, visibleRecord.id == records.last?.id else { return }
        reloadHistory(reset: false)
    }

    func select(
        record: ClipboardRecord,
        command: Bool,
        shift: Bool
    ) {
        isSearchFocused = false
        var modifiers: SelectionModifiers = []
        if command { modifiers.insert(.command) }
        if shift { modifiers.insert(.shift) }
        selection.select(id: record.id, records: records, modifiers: modifiers)
    }

    func beginSearch(with characters: String) {
        guard !characters.isEmpty else { return }
        isSearchFocused = true
        searchQuery.append(contentsOf: characters)
    }

    func deleteLastSearchCharacter() {
        guard !searchQuery.isEmpty else { return }
        searchQuery.removeLast()
        isSearchFocused = true
    }

    func deleteSelection() {
        let selected = selection.orderedRecords(from: records)
        guard !selected.isEmpty else { return }
        Task {
            do {
                for record in selected {
                    try await repository.delete(id: record.id)
                }
                reloadHistory(reset: true)
                refreshStorageSize()
                showNotice(
                    selected.count == 1 ? "Item deleted" : "\(selected.count) items deleted",
                    symbol: "trash"
                )
            } catch {
                show(error: error)
            }
        }
    }

    func clearHistory() {
        Task {
            do {
                try await repository.clear()
                records = []
                selection.clear()
                storageSize = 0
                showNotice("History cleared", symbol: "checkmark.circle.fill")
            } catch {
                show(error: error)
            }
        }
    }

    func refreshStorageSize() {
        Task {
            do {
                storageSize = try await repository.storageSize()
            } catch {
                show(error: error)
            }
        }
    }

    func refreshAccessibilityStatus() {
        accessibilityGranted = directPasteService.isAccessibilityGranted
    }

    @discardableResult
    func requestAccessibilityAccess() -> Bool {
        let granted = directPasteService.requestAccessibility()
        refreshAccessibilityStatus()
        if !granted {
            do {
                try accessibilityService.openSystemSettings()
            } catch {
                show(error: error)
            }
        }
        return granted
    }

    func setAppearance(_ appearance: AppAppearance) {
        UserDefaults.standard.set(appearance.rawValue, forKey: PreferencesKey.appearance)
        applyAppearance(appearance)
    }

    func showSettings() {
        if let settingsController {
            settingsController.showWindow(nil)
            settingsController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(rootView: SettingsView(model: self))
        let window = NSWindow(contentViewController: controller)
        window.title = "Passst Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 620, height: 560))
        window.minSize = NSSize(width: 560, height: 500)
        window.center()
        let windowController = NSWindowController(window: window)
        settingsController = windowController
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshStorageSize()
    }

    func showNotice(_ message: String, symbol: String) {
        noticeTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            notice = PanelNotice(message: message, symbol: symbol, isError: false)
        }
        noticeTask = Task {
            do {
                try await Task.sleep(for: .seconds(2.4))
            } catch {
                return
            }
            withAnimation(.easeIn(duration: 0.14)) {
                notice = nil
            }
        }
    }

    func show(error: Error) {
        noticeTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            notice = PanelNotice(
                message: error.localizedDescription,
                symbol: "exclamationmark.triangle.fill",
                isError: true
            )
        }
        noticeTask = Task {
            do {
                try await Task.sleep(for: .seconds(4))
            } catch {
                return
            }
            withAnimation(.easeIn(duration: 0.14)) {
                notice = nil
            }
        }
    }

    func thumbnailURL(for record: ClipboardRecord) async -> URL? {
        await repository.thumbnailURL(for: record)
    }

    func payload(for record: ClipboardRecord) async throws -> ClipboardPayload {
        try await repository.payload(for: record)
    }

    private func capture(
        _ payload: ClipboardPayload,
        sourceApplication: NSRunningApplication?
    ) {
        if sourceApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        let metadata = ClipboardPayloadClassifier.makeRecord(
            for: payload,
            sourceApplication: sourceApplication
        )
        Task {
            do {
                let saved = try await repository.save(payload: payload, metadata: metadata)
                if searchQuery.isEmpty {
                    withAnimation(
                        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.18)
                    ) {
                        records.removeAll { $0.id == saved.id }
                        records.insert(saved, at: 0)
                        selection.reset(records: records)
                    }
                } else {
                    reloadHistory(reset: true)
                }
                refreshStorageSize()
            } catch {
                show(error: error)
            }
        }
    }

    private func performSelectionAction(plainText: Bool, directPaste: Bool) {
        let selectedRecords = selection.orderedRecords(from: records)
        guard !selectedRecords.isEmpty else {
            show(error: SelectionPayloadBuilder.BuildError.emptySelection)
            return
        }

        Task {
            do {
                let payload = try await payloadBuilder.build(
                    records: selectedRecords,
                    plainTextOnly: plainText
                )
                let changeCount = try codec.write(payload)
                clipboardMonitor.suppress(changeCount: changeCount)
                CopyFeedbackPlayer.shared.play()

                if directPaste {
                    refreshAccessibilityStatus()
                    if !accessibilityGranted {
                        _ = requestAccessibilityAccess()
                        showNotice(
                            "Copied. Allow Accessibility, then press Enter again — or use Command+V.",
                            symbol: "hand.raised.fill"
                        )
                        return
                    }

                    let target = panelController.previouslyActiveApplication
                    previewedID = nil
                    previewPayload = nil
                    panelController.close { [weak self] in
                        guard let self else { return }
                        Task {
                            do {
                                try await self.directPasteService.paste(into: target)
                            } catch {
                                self.show(error: error)
                            }
                        }
                    }
                } else {
                    panelController.close()
                }
            } catch {
                show(error: error)
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch {
                return
            }
            reloadHistory(reset: true)
        }
    }

    private func reloadHistory(reset: Bool, animated: Bool = true) {
        guard !isLoading || reset else { return }
        activeLoadGeneration += 1
        let generation = activeLoadGeneration
        let query = searchQuery
        let offset = reset ? 0 : records.count
        isLoading = true

        Task {
            defer {
                if generation == activeLoadGeneration {
                    isLoading = false
                }
            }
            do {
                let page = try await repository.page(
                    query: query,
                    offset: offset,
                    limit: 100
                )
                guard generation == activeLoadGeneration else { return }
                let applyPage = { [self] in
                    self.records = reset ? page.records : self.records + page.records
                    self.hasMore = page.hasMore
                    self.selection.reset(
                        records: self.records,
                        preservingSelection: !reset
                    )
                }
                if animated {
                    withAnimation(
                        reduceMotion ? .easeOut(duration: 0.1) : .smooth(duration: 0.16),
                        applyPage
                    )
                } else {
                    applyPage()
                }
            } catch {
                guard generation == activeLoadGeneration else { return }
                show(error: error)
            }
        }
    }

    private func applyStoredAppearance() {
        let rawValue = UserDefaults.standard.string(forKey: PreferencesKey.appearance)
            ?? AppAppearance.system.rawValue
        applyAppearance(AppAppearance(rawValue: rawValue) ?? .system)
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.screensDidWakeNotification
        ] {
            let token = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.mediaRefreshGeneration &+= 1
                    self.reloadHistory(reset: true)
                }
            }
            workspaceObserverTokens.append(token)
        }
    }

    private func restoreRequestedShortcutIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(
            forKey: PreferencesKey.didRestoreShiftCommandShortcut
        ) else {
            return
        }

        let temporaryShortcut = KeyboardShortcuts.Shortcut(
            .v,
            modifiers: [.command, .option]
        )
        if KeyboardShortcuts.getShortcut(for: .togglePassst) == temporaryShortcut {
            KeyboardShortcuts.setShortcut(
                .init(.v, modifiers: [.command, .shift]),
                for: .togglePassst
            )
        }
        defaults.set(
            true,
            forKey: PreferencesKey.didRestoreShiftCommandShortcut
        )
    }

    private func installUITestFixtures() {
        Task {
            do {
                try await repository.clear()
                let fixtures = [
                    (
                        Self.uiTestFilePayload(),
                        "com.apple.finder",
                        "Finder"
                    ),
                    (
                        Self.uiTestImagePayload(),
                        "com.apple.Preview",
                        "Preview"
                    ),
                    (
                        ClipboardPayload.text("#3867F4"),
                        "com.apple.Notes",
                        "Notes"
                    ),
                    (
                        ClipboardPayload.text(
                            "https://developer.apple.com/documentation/swiftui"
                        ),
                        "com.apple.Safari",
                        "Safari"
                    ),
                    (
                        ClipboardPayload.text(
                            """
                            struct ClipboardItem: Identifiable {
                                let id: UUID
                                let preview: String
                            }
                            """
                        ),
                        "com.apple.Terminal",
                        "Terminal"
                    ),
                    (
                        ClipboardPayload.text(
                            """
                            Paste anything. Find it instantly.

                            Русский поиск по истории тоже работает.
                            """
                        ),
                        "com.apple.TextEdit",
                        "TextEdit"
                    )
                ]
                for (payload, bundleIdentifier, applicationName) in fixtures {
                    let metadata = ClipboardPayloadClassifier.makeRecord(
                        for: payload,
                        sourceBundleIdentifier: bundleIdentifier,
                        sourceApplicationName: applicationName
                    )
                    _ = try await repository.save(payload: payload, metadata: metadata)
                }
                reloadHistory(reset: true)
                refreshStorageSize()
                if ProcessInfo.processInfo.arguments.contains("--show-panel") {
                    presentPanel()
                }
            } catch {
                show(error: error)
            }
        }
    }

    private static func uiTestFilePayload() -> ClipboardPayload {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let encodedURL = Data(url.absoluteString.utf8)
        return ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(type: .fileURL, data: encodedURL),
                        PasteboardRepresentation(
                            type: .string,
                            data: Data("Safari.app".utf8)
                        )
                    ]
                )
            ],
            plainText: "Safari.app",
            fileURLs: [url]
        )
    }

    private static func uiTestImagePayload() -> ClipboardPayload {
        let size = NSSize(width: 720, height: 460)
        let image = NSImage(size: size)
        image.lockFocus()

        NSGradient(
            colors: [
                NSColor(calibratedRed: 0.14, green: 0.27, blue: 0.96, alpha: 1),
                NSColor(calibratedRed: 0.52, green: 0.30, blue: 0.98, alpha: 1)
            ]
        )?.draw(in: NSRect(origin: .zero, size: size), angle: -22)

        for (index, alpha) in ([CGFloat](arrayLiteral: 0.24, 0.38, 0.78)).enumerated() {
            let offset = CGFloat(index) * 64
            let rect = NSRect(
                x: 104 + offset,
                y: 74 + offset * 0.42,
                width: 330,
                height: 240
            )
            NSColor.white.withAlphaComponent(alpha).setFill()
            NSBezierPath(
                roundedRect: rect,
                xRadius: 46,
                yRadius: 46
            ).fill()
        }

        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            return ClipboardPayload.text("Passst image preview")
        }

        return ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(type: .png, data: png)
                    ]
                )
            ]
        )
    }

    private func applyAppearance(_ appearance: AppAppearance) {
        let application = NSApplication.shared
        switch appearance {
        case .system:
            application.appearance = nil
        case .light:
            application.appearance = NSAppearance(named: .aqua)
        case .dark:
            application.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

struct PanelNotice: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let symbol: String
    let isError: Bool
}
