import Foundation

struct ClipboardRecord: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var kind: ClipboardContentKind
    var createdAt: Date
    var updatedAt: Date
    var displayTitle: String
    var previewText: String
    var searchableText: String
    var sourceBundleIdentifier: String?
    var sourceApplicationName: String?
    var payloadFilename: String
    var thumbnailFilename: String?
    var payloadDigest: String
    var byteCount: Int64

    init(
        id: UUID = UUID(),
        kind: ClipboardContentKind,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        displayTitle: String,
        previewText: String,
        searchableText: String,
        sourceBundleIdentifier: String?,
        sourceApplicationName: String?,
        payloadFilename: String,
        thumbnailFilename: String?,
        payloadDigest: String,
        byteCount: Int64
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.displayTitle = displayTitle
        self.previewText = previewText
        self.searchableText = searchableText
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceApplicationName = sourceApplicationName
        self.payloadFilename = payloadFilename
        self.thumbnailFilename = thumbnailFilename
        self.payloadDigest = payloadDigest
        self.byteCount = byteCount
    }
}

struct HistoryPage: Sendable {
    let records: [ClipboardRecord]
    let hasMore: Bool
}
