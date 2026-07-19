import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageRepresentationNormalizer {
    static func addingPortablePNGIfNeeded(
        to representations: [PasteboardRepresentation]
    ) -> [PasteboardRepresentation] {
        guard !representations.contains(where: {
            $0.typeIdentifier == NSPasteboard.PasteboardType.png.rawValue
        }), let source = representations.first(where: {
            UTType($0.typeIdentifier)?.conforms(to: .image) == true
        }), let png = pngData(from: source.data)
        else {
            return representations
        }

        var normalized = representations
        normalized.append(PasteboardRepresentation(type: .png, data: png))
        return normalized
    }

    static func pngData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return destinationData as Data
    }
}
