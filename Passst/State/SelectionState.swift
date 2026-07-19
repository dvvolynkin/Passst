import Foundation
import Observation

struct SelectionModifiers: OptionSet, Sendable {
    let rawValue: Int

    static let command = SelectionModifiers(rawValue: 1 << 0)
    static let shift = SelectionModifiers(rawValue: 1 << 1)
}

@MainActor
@Observable
final class SelectionState {
    private(set) var focusedID: UUID?
    private(set) var anchorID: UUID?
    private(set) var orderedIDs: [UUID] = []

    var selectedIDs: Set<UUID> {
        Set(orderedIDs)
    }

    func reset(records: [ClipboardRecord], preservingSelection: Bool = true) {
        let validIDs = Set(records.map(\.id))
        if preservingSelection {
            orderedIDs.removeAll { !validIDs.contains($0) }
        } else {
            focusedID = nil
            anchorID = nil
            orderedIDs.removeAll()
        }
        if let focusedID, !validIDs.contains(focusedID) {
            self.focusedID = nil
        }
        if let anchorID, !validIDs.contains(anchorID) {
            self.anchorID = nil
        }

        if focusedID == nil, let first = records.first {
            focusedID = first.id
            anchorID = first.id
            if orderedIDs.isEmpty {
                orderedIDs = [first.id]
            }
        }
    }

    func select(
        id: UUID,
        records: [ClipboardRecord],
        modifiers: SelectionModifiers = []
    ) {
        guard records.contains(where: { $0.id == id }) else { return }

        if modifiers.contains(.shift), let anchorID,
           let anchorIndex = records.firstIndex(where: { $0.id == anchorID }),
           let targetIndex = records.firstIndex(where: { $0.id == id }) {
            let lower = min(anchorIndex, targetIndex)
            let upper = max(anchorIndex, targetIndex)
            let rangeIDs = records[lower...upper].map(\.id)
            if modifiers.contains(.command) {
                appendUnique(rangeIDs)
            } else {
                orderedIDs = rangeIDs
            }
            focusedID = id
            return
        }

        if modifiers.contains(.command) {
            if let index = orderedIDs.firstIndex(of: id) {
                orderedIDs.remove(at: index)
                if focusedID == id {
                    focusedID = orderedIDs.last
                }
            } else {
                orderedIDs.append(id)
                focusedID = id
            }
            anchorID = focusedID
            return
        }

        focusedID = id
        anchorID = id
        orderedIDs = [id]
    }

    func move(delta: Int, extending: Bool, records: [ClipboardRecord]) {
        guard !records.isEmpty else { return }
        let currentIndex = focusedID.flatMap { id in
            records.firstIndex(where: { $0.id == id })
        } ?? (delta >= 0 ? -1 : records.count)
        let targetIndex = min(max(currentIndex + delta, 0), records.count - 1)
        let targetID = records[targetIndex].id
        select(
            id: targetID,
            records: records,
            modifiers: extending ? [.shift] : []
        )
    }

    func selectAll(records: [ClipboardRecord]) {
        orderedIDs = records.map(\.id)
        focusedID = records.first?.id
        anchorID = records.first?.id
    }

    func clear() {
        focusedID = nil
        anchorID = nil
        orderedIDs.removeAll()
    }

    func selectionIndex(for id: UUID) -> Int? {
        orderedIDs.firstIndex(of: id).map { $0 + 1 }
    }

    func orderedRecords(from records: [ClipboardRecord]) -> [ClipboardRecord] {
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return orderedIDs.compactMap { recordsByID[$0] }
    }

    private func appendUnique(_ ids: [UUID]) {
        let existing = Set(orderedIDs)
        orderedIDs.append(contentsOf: ids.filter { !existing.contains($0) })
    }
}
