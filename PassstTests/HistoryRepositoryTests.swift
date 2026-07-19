import Foundation
import XCTest
@testable import Passst

final class HistoryRepositoryTests: XCTestCase {
    func testDuplicateMovesExistingRecordToFront() async throws {
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
        let originalPayload = ClipboardPayload.text("same payload")
        let originalRecord = makeRecord(payload: originalPayload, title: "Original")
        let first = try await repository.save(
            payload: originalPayload,
            metadata: originalRecord
        )

        try await Task.sleep(for: .milliseconds(20))
        let duplicateRecord = makeRecord(payload: originalPayload, title: "Duplicate")
        let second = try await repository.save(
            payload: originalPayload,
            metadata: duplicateRecord
        )
        let page = try await repository.page(query: "", offset: 0)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(page.records.count, 1)
        XCTAssertEqual(page.records.first?.id, first.id)
        XCTAssertGreaterThan(second.updatedAt, first.updatedAt)
    }

    func testSearchFindsRussianEnglishAndSourceApp() async throws {
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

        for (text, app) in [
            ("Счёт для клиента", "Mail"),
            ("Release checklist", "Notes")
        ] {
            let payload = ClipboardPayload.text(text)
            var record = makeRecord(payload: payload, title: text)
            record.sourceApplicationName = app
            record.searchableText += "\n\(app)"
            _ = try await repository.save(payload: payload, metadata: record)
        }

        let russian = try await repository.page(query: "счёт", offset: 0)
        let english = try await repository.page(query: "release", offset: 0)
        let application = try await repository.page(query: "Mail", offset: 0)

        XCTAssertEqual(russian.records.map(\.displayTitle), ["Счёт для клиента"])
        XCTAssertEqual(english.records.map(\.displayTitle), ["Release checklist"])
        XCTAssertEqual(application.records.map(\.sourceApplicationName), ["Mail"])
    }

    func testSearchExpressionCreatesSafePrefixTokens() {
        XCTAssertEqual(
            HistoryRepository.searchExpression(#"  русский "two words"  "#),
            #""русский"* AND """two"* AND "words"""*"#
        )
    }

    private func makeRecord(
        payload: ClipboardPayload,
        title: String
    ) -> ClipboardRecord {
        ClipboardRecord(
            kind: .text,
            displayTitle: title,
            previewText: title,
            searchableText: title,
            sourceBundleIdentifier: nil,
            sourceApplicationName: nil,
            payloadFilename: "",
            thumbnailFilename: nil,
            payloadDigest: payload.stableDigest,
            byteCount: payload.byteCount
        )
    }
}
