import Foundation

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum PreferencesKey {
    static let appearance = "appearance"
    static let monitorPaused = "monitorPaused"
    static let copySoundEnabled = "copySoundEnabled"
    static let excludedBundleIdentifiers = "excludedBundleIdentifiers"
    static let didMigratePasteConflictingShortcut =
        "didMigratePasteConflictingShortcut"
    static let didRestoreShiftCommandShortcut =
        "didRestoreShiftCommandShortcut"
}
