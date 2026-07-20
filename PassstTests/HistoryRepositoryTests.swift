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

    func testSearchFindsAccentedEnglishAndSourceApp() async throws {
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
            ("Invoice for café client", "Mail"),
            ("Release checklist", "Notes")
        ] {
            let payload = ClipboardPayload.text(text)
            var record = makeRecord(payload: payload, title: text)
            record.sourceApplicationName = app
            record.searchableText += "\n\(app)"
            _ = try await repository.save(payload: payload, metadata: record)
        }

        let accented = try await repository.page(query: "café", offset: 0)
        let english = try await repository.page(query: "release", offset: 0)
        let application = try await repository.page(query: "Mail", offset: 0)

        XCTAssertEqual(accented.records.map(\.displayTitle), ["Invoice for café client"])
        XCTAssertEqual(english.records.map(\.displayTitle), ["Release checklist"])
        XCTAssertEqual(application.records.map(\.sourceApplicationName), ["Mail"])
    }

    func testSearchExpressionCreatesSafePrefixTokens() {
        XCTAssertEqual(
            HistoryRepository.searchExpression(#"  résumé "two words"  "#),
            #""résumé"* AND """two"* AND "words"""*"#
        )
    }

    func testCategoryAssignmentFilteringAndRemoval() async throws {
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
        let categoryID = UUID()
        let firstPayload = ClipboardPayload.text("Categorized")
        let secondPayload = ClipboardPayload.text("Uncategorized")
        let first = try await repository.save(
            payload: firstPayload,
            metadata: makeRecord(payload: firstPayload, title: "Categorized")
        )
        _ = try await repository.save(
            payload: secondPayload,
            metadata: makeRecord(payload: secondPayload, title: "Uncategorized")
        )

        try await repository.setCategory(categoryID, for: first.id)

        let filtered = try await repository.page(
            query: "",
            categoryID: categoryID,
            offset: 0
        )
        XCTAssertEqual(filtered.records.map(\.id), [first.id])
        XCTAssertEqual(filtered.records.first?.categoryID, categoryID)

        try await repository.removeCategoryReferences(categoryID)
        let restored = try await repository.record(id: first.id)
        XCTAssertNil(restored?.categoryID)
    }

    func testRenameUpdatesRecordAndSearchIndex() async throws {
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
        let payload = ClipboardPayload.text("Opaque contents")
        let record = try await repository.save(
            payload: payload,
            metadata: makeRecord(payload: payload, title: "Original title")
        )

        try await repository.rename(id: record.id, title: "Quarterly archive")

        let renamed = try await repository.record(id: record.id)
        let search = try await repository.page(query: "quarterly", offset: 0)
        XCTAssertEqual(renamed?.displayTitle, "Quarterly archive")
        XCTAssertEqual(search.records.map(\.id), [record.id])
    }

    func testSearchFiltersCombineTypeSourceAndDate() async throws {
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
        let safariSource = ClipboardSourceFilter(
            bundleIdentifier: "com.apple.Safari",
            applicationName: "Safari"
        )

        let linkPayload = ClipboardPayload.text("https://developer.apple.com/swift")
        var linkRecord = makeRecord(payload: linkPayload, title: "Swift documentation")
        linkRecord.kind = .link
        linkRecord.sourceBundleIdentifier = safariSource.bundleIdentifier
        linkRecord.sourceApplicationName = safariSource.applicationName
        linkRecord.searchableText += "\nSafari"
        let link = try await repository.save(payload: linkPayload, metadata: linkRecord)

        let textPayload = ClipboardPayload.text("Swift notes")
        var textRecord = makeRecord(payload: textPayload, title: "Swift notes")
        textRecord.sourceBundleIdentifier = "com.apple.Notes"
        textRecord.sourceApplicationName = "Notes"
        textRecord.searchableText += "\nNotes"
        _ = try await repository.save(payload: textPayload, metadata: textRecord)

        let filters = ClipboardSearchFilters(
            kinds: [.link],
            source: safariSource,
            date: .today
        )
        let filtered = try await repository.page(
            query: "swift",
            filters: filters,
            offset: 0
        )
        let sources = try await repository.sourceApplications()

        XCTAssertEqual(filtered.records.map(\.id), [link.id])
        XCTAssertTrue(sources.contains(safariSource))
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
