import AppKit
import Foundation

actor PayloadStore {
    enum StoreError: LocalizedError {
        case applicationSupportUnavailable
        case invalidImageData

        var errorDescription: String? {
            switch self {
            case .applicationSupportUnavailable:
                "Passst could not locate Application Support."
            case .invalidImageData:
                "The copied image could not be decoded."
            }
        }
    }

    private let fileManager: FileManager
    let rootURL: URL
    let payloadsURL: URL
    let thumbnailsURL: URL

    init(fileManager: FileManager = .default, rootURL: URL? = nil) throws {
        self.fileManager = fileManager

        if let rootURL {
            self.rootURL = rootURL
        } else {
            guard let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw StoreError.applicationSupportUnavailable
            }
            self.rootURL = applicationSupport.appendingPathComponent("Passst", isDirectory: true)
        }

        self.payloadsURL = self.rootURL.appendingPathComponent("Payloads", isDirectory: true)
        self.thumbnailsURL = self.rootURL.appendingPathComponent("Thumbnails", isDirectory: true)

        try fileManager.createDirectory(at: payloadsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
    }

    func write(_ payload: ClipboardPayload, id: UUID) throws -> String {
        let filename = "\(id.uuidString).payload"
        let destination = payloadsURL.appendingPathComponent(filename)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(payload)
        try data.write(to: destination, options: .atomic)
        return filename
    }

    func read(filename: String) throws -> ClipboardPayload {
        let data = try Data(contentsOf: payloadsURL.appendingPathComponent(filename))
        return try PropertyListDecoder().decode(ClipboardPayload.self, from: data)
    }

    func writeThumbnail(from payload: ClipboardPayload, id: UUID) throws -> String? {
        guard let sourceData = payload.preferredImageData else {
            return nil
        }
        guard let image = NSImage(data: sourceData),
              let cgImage = image.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: [.interpolation: NSImageInterpolation.high]
              ) else {
            throw StoreError.invalidImageData
        }

        let maximumDimension: CGFloat = 560
        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(1, maximumDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )

        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        guard let thumbnail = context.makeImage() else { return nil }

        let representation = NSBitmapImageRep(cgImage: thumbnail)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            return nil
        }
        let filename = "\(id.uuidString).png"
        try png.write(
            to: thumbnailsURL.appendingPathComponent(filename),
            options: [.atomic, .completeFileProtectionUnlessOpen]
        )
        return filename
    }

    func thumbnailURL(filename: String?) -> URL? {
        guard let filename else { return nil }
        return thumbnailsURL.appendingPathComponent(filename)
    }

    func delete(payloadFilename: String, thumbnailFilename: String?) throws {
        let payloadURL = payloadsURL.appendingPathComponent(payloadFilename)
        if fileManager.fileExists(atPath: payloadURL.path) {
            try fileManager.removeItem(at: payloadURL)
        }
        if let thumbnailFilename {
            let thumbnailURL = thumbnailsURL.appendingPathComponent(thumbnailFilename)
            if fileManager.fileExists(atPath: thumbnailURL.path) {
                try fileManager.removeItem(at: thumbnailURL)
            }
        }
    }

    func removeAllPayloads() throws {
        for directory in [payloadsURL, thumbnailsURL] {
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func storageSize() throws -> Int64 {
        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
