import AppKit
import Foundation

@MainActor
final class AppIconProvider {
    static let shared = AppIconProvider()

    private var iconCache: [String: NSImage] = [:]
    private var colorCache: [String: NSColor] = [:]

    func icon(bundleIdentifier: String?) -> NSImage? {
        guard let bundleIdentifier else { return nil }
        if let cached = iconCache[bundleIdentifier] {
            return cached
        }
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        icon.size = NSSize(width: 64, height: 64)
        iconCache[bundleIdentifier] = icon
        return icon
    }

    func accentColor(
        bundleIdentifier: String?,
        fallback: NSColor
    ) -> NSColor {
        guard let bundleIdentifier,
              let icon = icon(bundleIdentifier: bundleIdentifier)
        else {
            return fallback
        }
        if let cached = colorCache[bundleIdentifier] {
            return cached
        }

        let sampled = dominantColor(in: icon) ?? fallback
        colorCache[bundleIdentifier] = sampled
        return sampled
    }

    private func dominantColor(in image: NSImage) -> NSColor? {
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 18,
            pixelsHigh: 18,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        image.draw(
            in: NSRect(x: 0, y: 0, width: 18, height: 18),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        var buckets: [Int: (red: CGFloat, green: CGFloat, blue: CGFloat, count: Int)] = [:]
        for y in 1..<17 {
            for x in 1..<17 {
                guard let color = representation.colorAt(x: x, y: y)?
                    .usingColorSpace(.deviceRGB),
                    color.alphaComponent > 0.45
                else {
                    continue
                }
                let saturation = max(
                    color.redComponent,
                    color.greenComponent,
                    color.blueComponent
                ) - min(
                    color.redComponent,
                    color.greenComponent,
                    color.blueComponent
                )
                guard saturation > 0.12 else { continue }
                let r = Int(color.redComponent * 5)
                let g = Int(color.greenComponent * 5)
                let b = Int(color.blueComponent * 5)
                let key = r * 100 + g * 10 + b
                var bucket = buckets[key] ?? (0, 0, 0, 0)
                bucket.red += color.redComponent
                bucket.green += color.greenComponent
                bucket.blue += color.blueComponent
                bucket.count += 1
                buckets[key] = bucket
            }
        }

        guard let best = buckets.values.max(by: { $0.count < $1.count }),
              best.count > 0
        else {
            return nil
        }
        let divisor = CGFloat(best.count)
        return NSColor(
            calibratedRed: best.red / divisor,
            green: best.green / divisor,
            blue: best.blue / divisor,
            alpha: 1
        )
    }
}
