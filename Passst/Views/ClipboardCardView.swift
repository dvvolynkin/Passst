import AppKit
import ImageIO
import SwiftUI

struct ClipboardCardView: View {
    @Bindable var model: AppModel
    let record: ClipboardRecord

    @State private var isHovered = false

    private var isSelected: Bool {
        model.selection.selectedIDs.contains(record.id)
    }

    private var selectionIndex: Int? {
        model.selection.selectionIndex(for: record.id)
    }

    private var accent: Color {
        Color(
            nsColor: AppIconProvider.shared.accentColor(
                bundleIdentifier: record.sourceBundleIdentifier,
                fallback: record.kind.fallbackAccent
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 52)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 236, height: 220)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.white.opacity(0.18),
                    lineWidth: isSelected ? 4 : 0.8
                )
        }
        .overlay(alignment: .topTrailing) {
            applicationIconNotch
        }
        .overlay(alignment: .topLeading) {
            if let selectionIndex, model.selection.orderedIDs.count > 1 {
                selectionBadge(selectionIndex)
                    .offset(x: -7, y: -7)
                    .transition(.scale(scale: 0.45).combined(with: .opacity))
            }
        }
        .shadow(
            color: .black.opacity(isSelected ? 0.29 : (isHovered ? 0.22 : 0.15)),
            radius: isSelected ? 14 : 9,
            y: isSelected ? 7 : 5
        )
        .scaleEffect(isSelected ? 1.007 : (isHovered ? 1.004 : 1))
        .offset(y: isHovered ? -1 : 0)
        .animation(.smooth(duration: 0.12), value: isHovered)
        .animation(
            model.reduceMotion ? .easeOut(duration: 0.1) : .smooth(duration: 0.16),
            value: isSelected
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            if !isSelected {
                model.select(record: record, command: false, shift: false)
            }
            model.pasteSelection(plainText: false)
        }
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            model.select(
                record: record,
                command: flags.contains(.command),
                shift: flags.contains(.shift)
            )
        }
        .contextMenu {
            Button("Copy") {
                if !isSelected {
                    model.select(record: record, command: false, shift: false)
                }
                model.copySelection()
            }
            Button("Paste") {
                if !isSelected {
                    model.select(record: record, command: false, shift: false)
                }
                model.pasteSelection(plainText: false)
            }
            Button("Paste as Plain Text") {
                if !isSelected {
                    model.select(record: record, command: false, shift: false)
                }
                model.pasteSelection(plainText: true)
            }
            Divider()
            Button("Delete", role: .destructive) {
                if !isSelected {
                    model.select(record: record, command: false, shift: false)
                }
                model.deleteSelection()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.kind.title), \(record.displayTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: record.kind.symbolName)
                .font(.system(size: 10, weight: .bold))
            Text(record.kind.title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.22)
            Text("·")
                .foregroundStyle(.secondary)
            Text(record.updatedAt, style: .relative)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 44)
        }
        .foregroundStyle(accent)
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(0.21),
                    accent.opacity(0.075)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    @ViewBuilder
    private var content: some View {
        switch record.kind {
        case .image:
            ThumbnailImageView(model: model, record: record)
        case .color:
            ColorPreviewView(value: record.previewText)
        case .files:
            FilePreviewView(model: model, record: record, accent: accent)
        case .link:
            LinkPreviewView(model: model, record: record, accent: accent)
        case .richText:
            RichTextCardContent(model: model, record: record)
        case .code:
            CodeCardContent(record: record)
        case .mixed:
            GenericCardContent(record: record, accent: accent)
        case .text:
            TextCardContent(record: record)
        }
    }

    private var cardBackground: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.94)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.13),
                    Color.black.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var applicationIconNotch: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 7,
                bottomLeadingRadius: 15,
                bottomTrailingRadius: 7,
                topTrailingRadius: 17
            )
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.82))
            .shadow(color: .black.opacity(0.1), radius: 3, x: -1, y: 2)

            if let icon = AppIconProvider.shared.icon(
                bundleIdentifier: record.sourceBundleIdentifier
            ) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 23))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 49, height: 49)
        .padding(.top, 2)
        .padding(.trailing, 2)
        .help(record.sourceApplicationName ?? "Unknown application")
    }

    private func selectionBadge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(minWidth: 23, minHeight: 23)
            .background(Color.accentColor, in: Circle())
            .overlay {
                Circle().stroke(.white.opacity(0.92), lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
            .animation(
                model.reduceMotion
                    ? .easeOut(duration: 0.1)
                    : .spring(duration: 0.16, bounce: 0.14),
                value: number
            )
    }
}

private struct TextCardContent: View {
    let record: ClipboardRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if record.displayTitle != record.previewText {
                Text(record.displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)
            }
            Text(record.previewText)
                .font(.system(size: 13.5, weight: .regular, design: .default))
                .lineSpacing(2.6)
                .lineLimit(7)
                .foregroundStyle(.primary.opacity(0.88))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

private struct RichTextCardContent: View {
    let model: AppModel
    let record: ClipboardRecord
    @State private var attributedText: AttributedString?

    var body: some View {
        Group {
            if let attributedText {
                Text(attributedText)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text(record.previewText)
                    .font(.system(size: 13.5))
                    .lineSpacing(2)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(14)
        .task(id: "\(record.id.uuidString)#\(model.mediaRefreshGeneration)") {
            do {
                let payload = try await model.payload(for: record)
                attributedText = try await RichTextDecoder.decode(payload)
            } catch {
                attributedText = nil
                model.show(error: error)
            }
        }
    }
}

private struct CodeCardContent: View {
    let record: ClipboardRecord
    @Environment(\.colorScheme) private var colorScheme
    @State private var highlighted: AttributedString?

    var body: some View {
        Group {
            if let highlighted {
                Text(highlighted)
            } else {
                Text(record.previewText)
                    .font(.system(size: 11.5, design: .monospaced))
            }
        }
        .lineSpacing(2.8)
        .lineLimit(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.18)
                : Color.black.opacity(0.035)
        )
        .task(id: "\(record.id.uuidString)#\(colorScheme)") {
            highlighted = await CodeHighlighter.highlight(
                record.previewText,
                darkMode: colorScheme == .dark,
                fontSize: 11.5
            )
        }
    }
}

private struct LinkPreviewView: View {
    let model: AppModel
    let record: ClipboardRecord
    let accent: Color
    @State private var preview: LinkPreviewData?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = preview?.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [
                        .clear,
                        .black.opacity(0.16),
                        .black.opacity(0.76)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                previewText(
                    title: preview?.title ?? record.displayTitle,
                    domain: preview?.domain ?? domain
                )
                .foregroundStyle(.white)
                .padding(14)
            } else {
                fallbackPreview
            }
        }
        .task(id: "\(record.id.uuidString)#\(model.mediaRefreshGeneration)") {
            preview = await LinkPreviewService.shared.preview(for: record.previewText)
        }
    }

    private var fallbackPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "safari.fill")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(accent)
            Spacer(minLength: 0)
            previewText(title: preview?.title ?? record.displayTitle, domain: domain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.12), accent.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func previewText(title: String, domain: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(3)
            Text(domain)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
                .opacity(0.78)
        }
    }

    private var domain: String {
        URL(string: record.previewText)?.host(percentEncoded: false)
            ?? URL(string: record.previewText)?.host()
            ?? record.displayTitle
    }
}

private struct FilePreviewView: View {
    let model: AppModel
    let record: ClipboardRecord
    let accent: Color
    @State private var fileIcon: NSImage?
    @State private var parentPath: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let fileIcon {
                    Image(nsImage: fileIcon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "doc.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(record.displayTitle)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(3)
                Text(parentPath ?? record.previewText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .task(id: "\(record.id.uuidString)#\(model.mediaRefreshGeneration)") {
            do {
                let payload = try await model.payload(for: record)
                guard let url = payload.fileURLs.first else { return }
                fileIcon = NSWorkspace.shared.icon(forFile: url.path)
                parentPath = url.deletingLastPathComponent().path
            } catch {
                fileIcon = nil
                parentPath = nil
                model.show(error: error)
            }
        }
    }
}

private struct GenericCardContent: View {
    let record: ClipboardRecord
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: record.kind.symbolName)
                .font(.system(size: 30))
                .foregroundStyle(accent)
            Text(record.displayTitle)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(2)
            Text(record.previewText)
                .font(.system(size: 12.5))
                .lineLimit(5)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

private struct ColorPreviewView: View {
    let value: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(passstHex: value) ?? .gray
            Text(value.uppercased())
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundStyle(contrastingForeground)
                .padding(14)
        }
    }

    private var contrastingForeground: Color {
        guard let nsColor = NSColor(passstHex: value)?.usingColorSpace(.deviceRGB) else {
            return .white
        }
        let luminance = 0.2126 * nsColor.redComponent
            + 0.7152 * nsColor.greenComponent
            + 0.0722 * nsColor.blueComponent
        return luminance > 0.58 ? .black : .white
    }
}

private struct ThumbnailImageView: View {
    let model: AppModel
    let record: ClipboardRecord
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.secondary.opacity(0.07)
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .clipped()
        .task(
            id: "\(record.thumbnailFilename ?? record.id.uuidString)#\(model.mediaRefreshGeneration)"
        ) {
            if let url = await model.thumbnailURL(for: record),
               let thumbnail = await Self.decode(url: url) {
                image = thumbnail
                return
            }

            do {
                let payload = try await model.payload(for: record)
                image = await Self.decode(data: payload.preferredImageData)
            } catch {
                image = nil
                model.show(error: error)
            }
        }
    }

    private static func decode(url: URL) async -> CGImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            )
        }.value
    }

    private static func decode(data: Data?) async -> CGImage? {
        await Task.detached(priority: .utility) {
            guard let data,
                  let source = CGImageSourceCreateWithData(data as CFData, nil)
            else {
                return nil
            }
            return CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            )
        }.value
    }
}

enum RichTextDecoder {
    static func decode(
        _ payload: ClipboardPayload,
        baseFontSize: CGFloat = 13.5
    ) async throws -> AttributedString? {
        try await Task.detached(priority: .utility) {
            var lastDecodingError: Error?

            if let data = payload.representationData(for: .rtf) {
                do {
                    let value = try NSAttributedString(
                        data: data,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil
                    )
                    return AttributedString(
                        normalize(value, baseFontSize: baseFontSize)
                    )
                } catch {
                    lastDecodingError = error
                }
            }

            if let data = payload.representationData(for: .html) {
                do {
                    let value = try NSAttributedString(
                        data: data,
                        options: [
                            .documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue
                        ],
                        documentAttributes: nil
                    )
                    return AttributedString(
                        normalize(value, baseFontSize: baseFontSize)
                    )
                } catch {
                    lastDecodingError = error
                }
            }

            if let lastDecodingError {
                throw lastDecodingError
            }
            return nil
        }.value
    }

    private static func normalize(
        _ source: NSAttributedString,
        baseFontSize: CGFloat
    ) -> NSAttributedString {
        let value = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: value.length)

        value.removeAttribute(.foregroundColor, range: fullRange)
        value.removeAttribute(.backgroundColor, range: fullRange)

        value.enumerateAttribute(.font, in: fullRange) { attribute, range, _ in
            let sourceFont = attribute as? NSFont
            let traits = sourceFont?.fontDescriptor.symbolicTraits ?? []
            let weight: NSFont.Weight = traits.contains(.bold) ? .semibold : .regular
            var descriptor = NSFont.systemFont(
                ofSize: baseFontSize,
                weight: weight
            ).fontDescriptor
            if traits.contains(.italic) {
                descriptor = descriptor.withSymbolicTraits(.italic)
            }
            let font = NSFont(descriptor: descriptor, size: baseFontSize)
                ?? NSFont.systemFont(ofSize: baseFontSize, weight: weight)
            value.addAttribute(.font, value: font, range: range)
        }

        value.enumerateAttribute(.paragraphStyle, in: fullRange) {
            attribute, range, _ in
            let style = (attribute as? NSParagraphStyle)?.mutableCopy()
                as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.lineSpacing = 2.2
            style.paragraphSpacing = min(style.paragraphSpacing, 6)
            style.paragraphSpacingBefore = min(style.paragraphSpacingBefore, 3)
            value.addAttribute(.paragraphStyle, value: style, range: range)
        }

        if value.length > 0 {
            value.addAttribute(
                .foregroundColor,
                value: NSColor.labelColor,
                range: fullRange
            )
        }
        return value
    }
}

private extension NSColor {
    convenience init?(passstHex value: String) {
        var hex = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        if hex.count == 3 || hex.count == 4 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6 || hex.count == 8,
              let raw = UInt64(hex, radix: 16)
        else {
            return nil
        }
        let hasAlpha = hex.count == 8
        let red = CGFloat((raw >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((raw >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((raw >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? CGFloat(raw & 0xFF) / 255 : 1
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

private extension Color {
    init?(passstHex value: String) {
        guard let color = NSColor(passstHex: value) else { return nil }
        self.init(nsColor: color)
    }
}
