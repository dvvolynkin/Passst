import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    typealias CaptureHandler = @MainActor (
        _ payload: ClipboardPayload,
        _ sourceApplication: NSRunningApplication?
    ) -> Void
    typealias ErrorHandler = @MainActor (_ error: Error) -> Void

    private let pasteboard: NSPasteboard
    private let codec: PasteboardCodec
    private let captureHandler: CaptureHandler
    private let errorHandler: ErrorHandler
    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressedChangeCounts: Set<Int> = []

    var isPaused: Bool {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: PreferencesKey.monitorPaused)
        }
    }

    init(
        pasteboard: NSPasteboard = .general,
        codec: PasteboardCodec,
        captureHandler: @escaping CaptureHandler,
        errorHandler: @escaping ErrorHandler
    ) {
        self.pasteboard = pasteboard
        self.codec = codec
        self.captureHandler = captureHandler
        self.errorHandler = errorHandler
        self.lastChangeCount = pasteboard.changeCount
        self.isPaused = UserDefaults.standard.bool(forKey: PreferencesKey.monitorPaused)
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.28, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func togglePaused() {
        isPaused.toggle()
    }

    func suppress(changeCount: Int) {
        suppressedChangeCounts.insert(changeCount)
        lastChangeCount = changeCount
    }

    private func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        if suppressedChangeCounts.remove(changeCount) != nil {
            return
        }
        guard !isPaused else { return }

        let sourceApplication = NSWorkspace.shared.frontmostApplication
        if isExcluded(sourceApplication) {
            return
        }

        do {
            let payload = try codec.capture(from: pasteboard)
            captureHandler(payload, sourceApplication)
        } catch PasteboardCodec.CodecError.concealedContent {
            return
        } catch PasteboardCodec.CodecError.emptyPasteboard {
            return
        } catch {
            errorHandler(error)
        }
    }

    private func isExcluded(_ application: NSRunningApplication?) -> Bool {
        guard let bundleIdentifier = application?.bundleIdentifier else { return false }
        let excluded = UserDefaults.standard.stringArray(
            forKey: PreferencesKey.excludedBundleIdentifiers
        ) ?? []
        return excluded.contains(bundleIdentifier)
    }
}
