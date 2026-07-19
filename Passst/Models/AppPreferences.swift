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
    static let categories = "categories"
    static let excludedBundleIdentifiers = "excludedBundleIdentifiers"
    static let didMigratePasteConflictingShortcut =
        "didMigratePasteConflictingShortcut"
    static let didRestoreShiftCommandShortcut =
        "didRestoreShiftCommandShortcut"
}

struct ClipboardCategory: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    static let palette = [
        "#FF5A67",
        "#FF9F0A",
        "#FFD60A",
        "#30D158",
        "#64D2FF",
        "#0A84FF",
        "#5E5CE6",
        "#BF5AF2"
    ]
}
