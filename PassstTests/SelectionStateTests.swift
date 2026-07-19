import XCTest
@testable import Passst

@MainActor
final class SelectionStateTests: XCTestCase {
    func testCommandSelectionPreservesClickOrder() {
        let records = makeRecords(count: 4)
        let selection = SelectionState()

        selection.select(id: records[2].id, records: records)
        selection.select(id: records[0].id, records: records, modifiers: [.command])
        selection.select(id: records[3].id, records: records, modifiers: [.command])

        XCTAssertEqual(
            selection.orderedIDs,
            [records[2].id, records[0].id, records[3].id]
        )
        XCTAssertEqual(selection.selectionIndex(for: records[0].id), 2)
    }

    func testShiftSelectionUsesVisibleRangeOrder() {
        let records = makeRecords(count: 5)
        let selection = SelectionState()

        selection.select(id: records[1].id, records: records)
        selection.select(id: records[4].id, records: records, modifiers: [.shift])

        XCTAssertEqual(selection.orderedIDs, Array(records[1...4].map(\.id)))
        XCTAssertEqual(selection.focusedID, records[4].id)
    }

    func testCommandClickTogglesOneItem() {
        let records = makeRecords(count: 3)
        let selection = SelectionState()

        selection.select(id: records[0].id, records: records)
        selection.select(id: records[1].id, records: records, modifiers: [.command])
        selection.select(id: records[0].id, records: records, modifiers: [.command])

        XCTAssertEqual(selection.orderedIDs, [records[1].id])
    }

    func testResetWithoutPreservingSelectionSelectsFirstRecord() {
        let records = makeRecords(count: 3)
        let selection = SelectionState()

        selection.select(id: records[2].id, records: records)
        selection.reset(records: records, preservingSelection: false)

        XCTAssertEqual(selection.focusedID, records[0].id)
        XCTAssertEqual(selection.anchorID, records[0].id)
        XCTAssertEqual(selection.orderedIDs, [records[0].id])
    }

    private func makeRecords(count: Int) -> [ClipboardRecord] {
        (0..<count).map { index in
            ClipboardRecord(
                kind: .text,
                displayTitle: "Item \(index)",
                previewText: "Item \(index)",
                searchableText: "Item \(index)",
                sourceBundleIdentifier: nil,
                sourceApplicationName: nil,
                payloadFilename: "\(index).payload",
                thumbnailFilename: nil,
                payloadDigest: "\(index)",
                byteCount: 8
            )
        }
    }
}
