import AppKit
import SwiftUI

@MainActor
enum PassstBrandAssets {
    static let monochromeMark: NSImage = {
        guard let url = Bundle.module.url(
            forResource: "PassstMenuBarTemplate",
            withExtension: "png"
        ), let image = NSImage(contentsOf: url) else {
            return NSImage(
                systemSymbolName: "square.stack.3d.up.fill",
                accessibilityDescription: "Passst"
            ) ?? NSImage()
        }
        image.isTemplate = true
        return image
    }()

    static var menuBarMark: NSImage {
        let image = monochromeMark.copy() as? NSImage ?? monochromeMark
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}

struct PassstBrandMark: View {
    var opacity = 1.0

    var body: some View {
        Image(nsImage: PassstBrandAssets.monochromeMark)
            .resizable()
            .interpolation(.high)
            .renderingMode(.template)
            .foregroundStyle(.primary)
            .opacity(opacity)
            .accessibilityLabel("Passst")
    }
}
