@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    @MainActor
    static let togglePassst = Self(
        "togglePassst",
        default: .init(.v, modifiers: [.command, .shift])
    )
}
