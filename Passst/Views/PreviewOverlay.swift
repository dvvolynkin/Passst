import AppKit
import ImageIO
import QuickLookUI
import SwiftUI

struct PreviewOverlay: View {
    @Bindable var model: AppModel
    let record: ClipboardRecord
    let payload: ClipboardPayload?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.42))
                .background(.ultraThinMaterial.opacity(0.16))
                .contentShape(Rectangle())
                .onTapGesture {
                    model.togglePreview()
                }
                .transition(.opacity)

            previewCard
                .frame(maxWidth: 760, maxHeight: 246)
                .padding(.horizontal, 45)
                .padding(.vertical, 22)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(
            model.reduceMotion
                ? .easeOut(duration: 0.14)
                : .spring(duration: 0.26, bounce: 0.08),
            value: record.id
        )
    }

    private var previewCard: some View {
        VStack(spacing: 0) {
            previewHeader
                .frame(height: 44)
            Divider()
            previewContent
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.42), radius: 32, y: 15)
    }

    private var previewHeader: some View {
        HStack(spacing: 9) {
            Image(systemName: record.kind.symbolName)
                .foregroundStyle(
                    Color(
                        nsColor: AppIconProvider.shared.accentColor(
                            bundleIdentifier: record.sourceBundleIdentifier,
                            fallback: record.kind.fallbackAccent
                        )
                    )
                )
            Text(record.displayTitle)
                .font(.system(size: 13.5, weight: .bold))
                .lineLimit(1)
            Text(record.sourceApplicationName ?? "")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("←  →")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
            Button {
                model.togglePreview()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 11)
    }

    @ViewBuilder
    private var previewContent: some View {
        if let payload {
            switch record.kind {
            case .image:
                LargeImagePreview(payload: payload)
            case .files:
                if let url = payload.fileURLs.first {
                    QuickLookPreview(url: url)
                } else {
                    textPreview(record.previewText)
                }
            case .color:
                ZStack {
                    Color(passstPreviewHex: record.previewText) ?? .gray
                    Text(record.previewText.uppercased())
                        .font(.system(size: 25, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
            case .richText:
                LargeRichTextPreview(
                    model: model,
                    payload: payload,
                    fallback: record.previewText
                )
            case .code:
                LargeCodePreview(record: record)
            case .link:
                LargeLinkPreview(
                    model: model,
                    record: record
                )
            case .text, .mixed:
                textPreview(payload.plainText ?? record.previewText)
            }
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func textPreview(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .textSelection(.enabled)
                .font(.system(size: 15))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(18)
        }
        .scrollIndicators(.automatic)
    }

}

private struct LargeCodePreview: View {
    let record: ClipboardRecord
    @Environment(\.colorScheme) private var colorScheme
    @State private var highlighted: AttributedString?

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                Group {
                    if let highlighted {
                        Text(highlighted)
                    } else {
                        Text(record.previewText)
                            .font(.system(size: 14, design: .monospaced))
                    }
                }
                .textSelection(.enabled)
                .lineSpacing(3.2)
                .fixedSize(horizontal: true, vertical: false)
                .frame(
                    minWidth: geometry.size.width,
                    minHeight: geometry.size.height,
                    alignment: .topLeading
                )
                .padding(18)
            }
        }
        .background(
            colorScheme == .dark
                ? Color.black.opacity(0.2)
                : Color.black.opacity(0.03)
        )
        .task(id: "\(record.id.uuidString)#\(colorScheme)") {
            highlighted = await CodeHighlighter.highlight(
                record.previewText,
                darkMode: colorScheme == .dark,
                fontSize: 14
            )
        }
    }
}

private struct LargeLinkPreview: View {
    let model: AppModel
    let record: ClipboardRecord
    @State private var preview: LinkPreviewData?

    var body: some View {
        HStack(spacing: 0) {
            media
                .frame(width: 300)

            VStack(alignment: .leading, spacing: 8) {
                Text(preview?.title ?? record.displayTitle)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(3)

                Label(preview?.domain ?? domain, systemImage: "globe")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(record.previewText)
                    .textSelection(.enabled)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .task(id: "\(record.id.uuidString)#\(model.mediaRefreshGeneration)") {
            preview = await LinkPreviewService.shared.preview(for: record.previewText)
        }
    }

    @ViewBuilder
    private var media: some View {
        if let image = preview?.image {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.2),
                        Color.accentColor.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "safari.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var domain: String {
        URL(string: record.previewText)?.host(percentEncoded: false)
            ?? URL(string: record.previewText)?.host()
            ?? record.displayTitle
    }
}

private struct LargeImagePreview: View {
    let payload: ClipboardPayload
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.09))
        .task {
            image = await Task.detached(priority: .utility) {
                guard let data = payload.preferredImageData,
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
}

private struct LargeRichTextPreview: View {
    let model: AppModel
    let payload: ClipboardPayload
    let fallback: String
    @State private var value: AttributedString?

    var body: some View {
        ScrollView {
            Group {
                if let value {
                    Text(value)
                } else {
                    Text(fallback)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(18)
        }
        .task {
            do {
                value = try await RichTextDecoder.decode(payload, baseFontSize: 15)
            } catch {
                value = nil
                model.show(error: error)
            }
        }
    }
}

private struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact)
        view?.autostarts = true
        view?.previewItem = url as NSURL
        return view ?? QLPreviewView()
    }

    func updateNSView(_ view: QLPreviewView, context: Context) {
        view.previewItem = url as NSURL
    }
}

private extension Color {
    init?(passstPreviewHex value: String) {
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
        let alphaBytes = hex.count == 8
        let red = Double((raw >> (alphaBytes ? 24 : 16)) & 0xFF) / 255
        let green = Double((raw >> (alphaBytes ? 16 : 8)) & 0xFF) / 255
        let blue = Double((raw >> (alphaBytes ? 8 : 0)) & 0xFF) / 255
        let alpha = alphaBytes ? Double(raw & 0xFF) / 255 : 1
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
