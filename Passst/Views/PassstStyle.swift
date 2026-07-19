import AppKit
import SwiftUI

enum PassstStyle {
    static let panelCornerRadius: CGFloat = 24
    static let toolbarHeight: CGFloat = 58

    static let cardWidth: CGFloat = 244
    static let cardHeight: CGFloat = 228
    static let cardHeaderHeight: CGFloat = 56
    static let cardCornerRadius: CGFloat = 18
    static let cardSpacing: CGFloat = 12

    static let panelHorizontalPadding: CGFloat = 20
    static let historyTopPadding: CGFloat = 12
    static let historyBottomPadding: CGFloat = 22
}

extension ClipboardContentKind {
    var cardAccent: Color {
        switch self {
        case .text, .richText:
            Color(red: 1.00, green: 0.64, blue: 0.00)
        case .code:
            Color(red: 0.04, green: 0.52, blue: 1.00)
        case .link:
            Color(red: 0.16, green: 0.75, blue: 0.39)
        case .image:
            Color(red: 1.00, green: 0.23, blue: 0.31)
        case .color:
            Color(red: 0.10, green: 0.68, blue: 0.65)
        case .files:
            Color(red: 0.49, green: 0.42, blue: 0.95)
        case .mixed:
            Color(red: 0.39, green: 0.46, blue: 0.55)
        }
    }

    var prefersDarkHeaderText: Bool {
        switch self {
        case .text, .richText:
            true
        default:
            false
        }
    }
}

extension Color {
    init(categoryHex value: String) {
        self.init(nsColor: NSColor(categoryHex: value))
    }
}

extension NSColor {
    convenience init(categoryHex value: String) {
        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let raw = UInt64(hex, radix: 16) ?? 0x0A84FF
        self.init(
            red: CGFloat((raw >> 16) & 0xFF) / 255,
            green: CGFloat((raw >> 8) & 0xFF) / 255,
            blue: CGFloat(raw & 0xFF) / 255,
            alpha: 1
        )
    }
}
