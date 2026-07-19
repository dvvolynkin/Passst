import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AccessibilityService {
    enum AccessibilityError: LocalizedError {
        case settingsUnavailable

        var errorDescription: String? {
            "Passst could not open the Accessibility settings."
        }
    }

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestIfNeeded() -> Bool {
        guard !isTrusted else { return true }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openSystemSettings() throws {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ), NSWorkspace.shared.open(url) else {
            throw AccessibilityError.settingsUnavailable
        }
    }
}

@MainActor
final class DirectPasteService {
    enum PasteError: LocalizedError {
        case targetApplicationUnavailable
        case eventCreationFailed

        var errorDescription: String? {
            switch self {
            case .targetApplicationUnavailable:
                "The application that was active before Passst could not be restored."
            case .eventCreationFailed:
                "Passst could not synthesize Command+V."
            }
        }
    }

    private let accessibility: AccessibilityService

    init(accessibility: AccessibilityService) {
        self.accessibility = accessibility
    }

    var isAccessibilityGranted: Bool {
        accessibility.isTrusted
    }

    func requestAccessibility() -> Bool {
        accessibility.requestIfNeeded()
    }

    func paste(into target: NSRunningApplication?) async throws {
        guard accessibility.isTrusted else {
            accessibility.requestIfNeeded()
            return
        }
        guard let target, !target.isTerminated else {
            throw PasteError.targetApplicationUnavailable
        }

        target.activate(options: [])
        try await Task.sleep(for: .milliseconds(55))
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            throw PasteError.eventCreationFailed
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
