import AppKit
import ImageIO
import SwiftUI

struct ClipboardCardView: View {
    @Bindable var model: AppModel
    let record: ClipboardRecord

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var renamePresented = false
    @State private var renameTitle = ""
    @State private var categoryCreatorPresented = false
    @State private var categoryName = ""

    private var isSelected: Bool {
        model.selection.selectedIDs.contains(record.id)
    }

    private var selectionIndex: Int? {
        model.selection.selectionIndex(for: record.id)
    }

    private var accent: Color {
        record.kind.cardAccent
    }

    private var headerTextColor: Color {
        record.kind.prefersDarkHeaderText
            ? Color.black.opacity(0.86)
            : Color.white.opacity(0.98)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: PassstStyle.cardHeaderHeight)
            content
                .frame(maxWidth: .infinity)
                .frame(
                    height: PassstStyle.cardHeight - PassstStyle.cardHeaderHeight
                )
        }
        .frame(width: PassstStyle.cardWidth, height: PassstStyle.cardHeight)
        .background(cardBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PassstStyle.cardCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            if isSelected {
                RoundedRectangle(
                    cornerRadius: PassstStyle.cardCornerRadius,
                    style: .continuous
                )
                .stroke(Color.accentColor, lineWidth: 2.5)
            }
        }
        .overlay(alignment: .topTrailing) {
            applicationIconNotch
        }
        .overlay(alignment: .topLeading) {
            if let selectionIndex, model.selection.orderedIDs.count > 1 {
                selectionBadge(selectionIndex)
                    .offset(x: -3, y: -3)
                    .transition(.scale(scale: 0.45).combined(with: .opacity))
            }
        }
        .shadow(
            color: .black.opacity(isHovered ? 0.18 : 0.13),
            radius: isHovered ? 14 : 10,
            y: isHovered ? 7 : 5
        )
        .offset(y: isHovered ? -2 : 0)
        .animation(.smooth(duration: 0.12), value: isHovered)
        .animation(
            model.reduceMotion ? .easeOut(duration: 0.1) : .smooth(duration: 0.16),
            value: isSelected
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: PassstStyle.cardCornerRadius,
                style: .continuous
            )
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrag {
            if !isSelected {
                model.select(record: record, command: false, shift: false)
            }
            return model.dragItemProvider(for: record)
        }
        .help("Drag to another app or onto a pinboard")
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
            Button(record.kind == .link ? "Paste Link" : "Paste") {
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
            Button(record.kind == .link ? "Copy Link" : "Copy") {
                if !isSelected {
                    model.select(record: record, command: false, shift: false)
                }
                model.copySelection()
            }
            Divider()
            Button("Rename…") {
                renameTitle = record.displayTitle
                renamePresented = true
            }
            Menu("Pin") {
                if record.categoryID != nil {
                    Button {
                        model.assign(record, to: nil)
                    } label: {
                        Label("Unpin", systemImage: "pin.slash")
                    }
                    Divider()
                }

                if !model.categories.isEmpty {
                    ForEach(model.categories) { category in
                        Button {
                            model.assign(record, to: category)
                        } label: {
                            Label(
                                category.name,
                                systemImage: record.categoryID == category.id
                                    ? "checkmark.circle.fill"
                                    : "pin.fill"
                            )
                        }
                    }
                    Divider()
                }

                Button("New Pinboard…") {
                    categoryName = ""
                    categoryCreatorPresented = true
                }
            }
            Divider()
            Button("Delete", role: .destructive) {
                if !isSelected {
                    model.select(record: record, command: false, shift: false)
                }
                model.deleteSelection()
            }
        }
        .alert("Rename Item", isPresented: $renamePresented) {
            TextField("Title", text: $renameTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                model.rename(record, to: renameTitle)
            }
            .disabled(
                renameTitle
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        } message: {
            Text("This changes only the title in Passst, not the original file.")
        }
        .alert("New Pinboard", isPresented: $categoryCreatorPresented) {
            TextField("Name", text: $categoryName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let color = ClipboardCategory.palette[
                    model.categories.count % ClipboardCategory.palette.count
                ]
                if let category = model.addCategory(
                    name: categoryName,
                    colorHex: color
                ) {
                    model.assign(record, to: category)
                }
            }
            .disabled(
                categoryName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        } message: {
            Text("The new pinboard will be assigned to this item.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.kind.title), \(record.displayTitle)")
        .accessibilityHint(
            record.kind == .link
                ? "Drag, copy, or paste the web address, not its thumbnail"
                : "Drag to another app or onto a pinboard"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.displayTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(headerTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .help(record.displayTitle)

            HStack(alignment: .center, spacing: 5) {
                Text(record.kind.title)
                    .font(.system(size: 12, weight: .regular))

                Text("·")

                Text(compactAge(at: .now))
                    .font(.system(size: 12, weight: .regular))
            }
            .foregroundStyle(headerTextColor.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.trailing, 48)
        .background(accent)
    }

    private func compactAge(at now: Date) -> String {
        let interval = max(0, now.timeIntervalSince(record.updatedAt))
        if interval < 60 {
            return "Now"
        }
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = Int(interval / 3_600)
        if hours < 24 {
            return "\(hours) h"
        }
        if Calendar.autoupdatingCurrent.isDateInYesterday(record.updatedAt) {
            return "Yesterday"
        }
        let days = Int(interval / 86_400)
        if days < 7 {
            return "\(days) d"
        }
        return record.updatedAt.formatted(
            .dateTime.month(.abbreviated).day()
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
        colorScheme == .dark
            ? Color(red: 0.135, green: 0.14, blue: 0.155)
            : Color.white.opacity(0.97)
    }

    private var applicationIconNotch: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: PassstStyle.cardCornerRadius
            )
            .fill(
                colorScheme == .dark
                    ? Color(red: 0.135, green: 0.14, blue: 0.155)
                    : Color.white.opacity(0.96)
            )

            if let icon = AppIconProvider.shared.icon(
                bundleIdentifier: record.sourceBundleIdentifier
            ) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: PassstStyle.cardHeaderHeight)
        .help(record.sourceApplicationName ?? "Unknown application")
    }

    private func selectionBadge(_ number: Int) -> some View {
        Text("\(number)")
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(minWidth: 20, minHeight: 20)
            .background(Color.accentColor, in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(bodyText)
                .font(.system(size: 13.5, weight: .regular, design: .default))
                .lineSpacing(2)
                .lineLimit(8)
                .foregroundStyle(.primary.opacity(0.88))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var bodyText: String {
        let preview = record.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard preview.hasPrefix(record.displayTitle) else {
            return preview
        }
        let remainder = preview
            .dropFirst(record.displayTitle.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty ? preview : remainder
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
        .padding(16)
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
                    .font(.system(size: 12.5, design: .monospaced))
            }
        }
        .lineSpacing(2)
        .lineLimit(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.18)
                : Color.black.opacity(0.035)
        )
        .task(id: "\(record.id.uuidString)#\(colorScheme)") {
            highlighted = await CodeHighlighter.highlight(
                record.previewText,
                darkMode: colorScheme == .dark,
                fontSize: 12.5
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(preview?.domain ?? domain)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "link")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(accent)

                Text(preview?.title ?? record.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(3)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Text(record.previewText)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            previewThumbnail
                .frame(width: 74, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 5, y: 3)
        }
        .padding(14)
        .task(id: "\(record.id.uuidString)#\(model.mediaRefreshGeneration)") {
            preview = await LinkPreviewService.shared.preview(for: record.previewText)
        }
    }

    @ViewBuilder
    private var previewThumbnail: some View {
        if let image = preview?.image {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 74, height: 110)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [accent.opacity(0.24), accent.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "safari.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(accent)
            }
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
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 8) {
                Text(parentPath ?? record.previewText)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.84))
                    .lineLimit(4)
                Text("Original file")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
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
                .font(.system(size: 28))
                .foregroundStyle(accent)
            Text(record.previewText)
                .font(.system(size: 13.5))
                .lineSpacing(2)
                .lineLimit(6)
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
        Color(passstHex: value) ?? .gray
    }
}

private struct ThumbnailImageView: View {
    let model: AppModel
    let record: ClipboardRecord
    @State private var image: CGImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if loadFailed {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 25, weight: .regular))
                    Text("Preview unavailable")
                        .font(.system(size: 13.5, weight: .medium))
                    Text("The original image can still be copied or dragged.")
                        .font(.system(size: 11.5))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 170)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.035))
            } else {
                ZStack {
                    Color.primary.opacity(0.035)
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .clipped()
        .task(
            id: "\(record.thumbnailFilename ?? record.id.uuidString)#\(model.mediaRefreshGeneration)"
        ) {
            loadFailed = false
            if let url = await model.thumbnailURL(for: record),
               let thumbnail = await Self.decode(url: url) {
                image = thumbnail
                return
            }

            do {
                let payload = try await model.payload(for: record)
                image = await Self.decode(data: payload.preferredImageData)
                loadFailed = image == nil
            } catch {
                image = nil
                loadFailed = true
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
