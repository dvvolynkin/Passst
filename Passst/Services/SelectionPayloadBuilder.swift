import AppKit
import Foundation

actor SelectionPayloadBuilder {
    enum BuildError: LocalizedError {
        case emptySelection
        case noPlainText

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                "Select at least one item first."
            case .noPlainText:
                "This selection cannot be converted to plain text."
            }
        }
    }

    private let repository: HistoryRepository

    init(repository: HistoryRepository) {
        self.repository = repository
    }

    func build(records: [ClipboardRecord], plainTextOnly: Bool) async throws -> ClipboardPayload {
        guard !records.isEmpty else { throw BuildError.emptySelection }

        var payloads: [ClipboardPayload] = []
        for record in records {
            payloads.append(try await repository.payload(for: record))
        }

        if plainTextOnly {
            let parts = payloads.compactMap(Self.plainTextFallback)
            guard !parts.isEmpty else { throw BuildError.noPlainText }
            return .text(parts.joined(separator: "\n"))
        }

        if payloads.count == 1, let only = payloads.first {
            return only
        }

        let allAreFiles = payloads.allSatisfy { !$0.fileURLs.isEmpty }
        if allAreFiles {
            let urls = payloads.flatMap(\.fileURLs)
            let items = urls.map { url in
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(
                            type: .fileURL,
                            data: Data(url.absoluteString.utf8)
                        )
                    ]
                )
            }
            return ClipboardPayload(
                items: items,
                plainText: urls.map(\.path).joined(separator: "\n"),
                fileURLs: urls
            )
        }

        let joinedText = payloads.compactMap(Self.plainTextFallback).joined(separator: "\n")
        let textualKinds: Set<ClipboardContentKind> = [
            .text,
            .richText,
            .code,
            .link,
            .color
        ]
        let containsOnlyTextualContent = records.allSatisfy {
            textualKinds.contains($0.kind)
        }

        if containsOnlyTextualContent, !joinedText.isEmpty {
            return .text(joinedText)
        }

        var items = payloads.flatMap(\.items)
        if !joinedText.isEmpty {
            let fallback = PasteboardRepresentation(type: .string, data: Data(joinedText.utf8))
            if items.isEmpty {
                items = [ClipboardPayloadItem(representations: [fallback])]
            } else {
                items[0].representations.removeAll {
                    $0.typeIdentifier == NSPasteboard.PasteboardType.string.rawValue
                }
                items[0].representations.append(fallback)
            }
        }

        return ClipboardPayload(
            items: items,
            plainText: joinedText.isEmpty ? nil : joinedText,
            fileURLs: payloads.flatMap(\.fileURLs)
        )
    }

    private static func plainTextFallback(_ payload: ClipboardPayload) -> String? {
        if let plainText = payload.plainText, !plainText.isEmpty {
            return plainText
        }
        if !payload.fileURLs.isEmpty {
            return payload.fileURLs.map(\.path).joined(separator: "\n")
        }
        return nil
    }
}
