import AppKit
import Foundation

enum ClipboardContentKind: String, Codable, CaseIterable, Sendable {
    case text
    case richText
    case code
    case link
    case image
    case color
    case files
    case mixed

    var title: String {
        switch self {
        case .text: "Text"
        case .richText: "Rich Text"
        case .code: "Code"
        case .link: "Link"
        case .image: "Image"
        case .color: "Color"
        case .files: "Files"
        case .mixed: "Mixed"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .link: "link"
        case .image: "photo"
        case .color: "paintpalette.fill"
        case .files: "doc.on.doc"
        case .mixed: "square.stack.3d.up.fill"
        }
    }

    var fallbackAccent: NSColor {
        switch self {
        case .text: .systemOrange
        case .richText: .systemPurple
        case .code: .systemCyan
        case .link: .systemBlue
        case .image: .systemPink
        case .color: .systemTeal
        case .files: .systemIndigo
        case .mixed: .systemGreen
        }
    }
}
