import AppKit
import Foundation
import XCTest
@testable import Passst

final class SelectionPayloadBuilderTests: XCTestCase {
    func testMultipleTextsFollowSelectionOrder() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PassstTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                XCTFail("Could not clean test data: \(error)")
            }
        }
        let repository = try HistoryRepository(rootURL: root)
        var records: [ClipboardRecord] = []

        for value in ["third", "first", "second"] {
            let payload = ClipboardPayload.text(value)
            let metadata = ClipboardRecord(
                kind: .text,
                displayTitle: value,
                previewText: value,
                searchableText: value,
                sourceBundleIdentifier: nil,
                sourceApplicationName: nil,
                payloadFilename: "",
                thumbnailFilename: nil,
                payloadDigest: payload.stableDigest,
                byteCount: payload.byteCount
            )
            records.append(
                try await repository.save(payload: payload, metadata: metadata)
            )
        }

        let result = try await SelectionPayloadBuilder(repository: repository).build(
            records: records,
            plainTextOnly: false
        )

        XCTAssertEqual(result.plainText, "third\nfirst\nsecond")
    }

    func testPlainTextModeUsesFilePaths() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PassstTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                XCTFail("Could not clean test data: \(error)")
            }
        }
        let repository = try HistoryRepository(rootURL: root)
        let url = URL(fileURLWithPath: "/tmp/Passst Test.txt")
        let payload = ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(
                            type: .fileURL,
                            data: Data(url.absoluteString.utf8)
                        )
                    ]
                )
            ],
            fileURLs: [url]
        )
        let metadata = ClipboardRecord(
            kind: .files,
            displayTitle: url.lastPathComponent,
            previewText: url.path,
            searchableText: url.path,
            sourceBundleIdentifier: nil,
            sourceApplicationName: nil,
            payloadFilename: "",
            thumbnailFilename: nil,
            payloadDigest: payload.stableDigest,
            byteCount: payload.byteCount
        )
        let record = try await repository.save(payload: payload, metadata: metadata)

        let result = try await SelectionPayloadBuilder(repository: repository).build(
            records: [record],
            plainTextOnly: true
        )

        XCTAssertEqual(result.plainText, url.path)
    }
}
