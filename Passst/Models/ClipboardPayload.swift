import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct PasteboardRepresentation: Codable, Hashable, Sendable {
    let typeIdentifier: String
    let data: Data

    init(typeIdentifier: String, data: Data) {
        self.typeIdentifier = typeIdentifier
        self.data = data
    }

    init(type: NSPasteboard.PasteboardType, data: Data) {
        self.init(typeIdentifier: type.rawValue, data: data)
    }

    var pasteboardType: NSPasteboard.PasteboardType {
        NSPasteboard.PasteboardType(typeIdentifier)
    }
}

struct ClipboardPayloadItem: Codable, Hashable, Sendable {
    var representations: [PasteboardRepresentation]

    init(representations: [PasteboardRepresentation]) {
        self.representations = representations
    }

    func representation(for type: NSPasteboard.PasteboardType) -> PasteboardRepresentation? {
        representations.first { $0.typeIdentifier == type.rawValue }
    }
}

struct ClipboardPayload: Codable, Hashable, Sendable {
    var items: [ClipboardPayloadItem]
    var plainText: String?
    var fileURLs: [URL]

    init(
        items: [ClipboardPayloadItem],
        plainText: String? = nil,
        fileURLs: [URL] = []
    ) {
        self.items = items
        self.plainText = plainText
        self.fileURLs = fileURLs
    }

    var byteCount: Int64 {
        Int64(items.lazy.flatMap(\.representations).reduce(0) { $0 + $1.data.count })
    }

    var stableDigest: String {
        var hasher = SHA256()
        for item in items {
            hasher.update(data: Data([0x1E]))
            for representation in item.representations.sorted(by: {
                $0.typeIdentifier < $1.typeIdentifier
            }) {
                hasher.update(data: Data(representation.typeIdentifier.utf8))
                hasher.update(data: Data([0]))
                hasher.update(data: representation.data)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func representationData(for type: NSPasteboard.PasteboardType) -> Data? {
        items.lazy.compactMap { $0.representation(for: type)?.data }.first
    }

    var preferredImageData: Data? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = representationData(for: type) {
                return data
            }
        }

        return items
            .lazy
            .flatMap(\.representations)
            .first { representation in
                UTType(representation.typeIdentifier)?.conforms(to: .image) == true
            }?
            .data
    }

    var referencedWebImageURL: URL? {
        let htmlRepresentations = items
            .lazy
            .compactMap { $0.representation(for: .html)?.data }

        for data in htmlRepresentations {
            guard let html = String(data: data, encoding: .utf8) else { continue }
            let patterns = [
                #"<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["']"#,
                #"<img\b[^>]*\bdata-src\s*=\s*["']([^"']+)["']"#
            ]
            for pattern in patterns {
                guard let match = html.range(
                    of: pattern,
                    options: [.regularExpression, .caseInsensitive]
                ) else {
                    continue
                }
                let element = String(html[match])
                guard let valueRange = element.range(
                    of: #"https?://[^"']+"#,
                    options: [.regularExpression, .caseInsensitive]
                ) else {
                    continue
                }
                let value = element[valueRange]
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#38;", with: "&")
                guard let url = URL(string: value),
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                else {
                    continue
                }
                return url
            }
        }
        return nil
    }
}

extension ClipboardPayload {
    static func text(_ value: String) -> ClipboardPayload {
        let data = value.data(using: .utf8) ?? Data()
        return ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(type: .string, data: data)
                    ]
                )
            ],
            plainText: value
        )
    }
}
