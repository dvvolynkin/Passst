import AppKit
import Foundation
import ImageIO

enum WebImageMaterializer {
    private static let maximumDownloadSize = 128 * 1_024 * 1_024

    static func materialize(_ payload: ClipboardPayload) async -> ClipboardPayload {
        guard payload.preferredImageData == nil,
              let url = payload.referencedWebImageURL
        else {
            return payload
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 8
        request.setValue(
            "Mozilla/5.0 (Macintosh; Passst clipboard image)",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let response = response as? HTTPURLResponse {
                guard (200 ... 299).contains(response.statusCode) else {
                    return payload
                }
                if response.expectedContentLength > maximumDownloadSize {
                    return payload
                }
            }
            guard data.count <= maximumDownloadSize,
                  let png = ImageRepresentationNormalizer.pngData(from: data)
            else {
                return payload
            }

            var materialized = payload
            materialized.items.append(
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(type: .png, data: png)
                    ]
                )
            )
            return materialized
        } catch {
            return payload
        }
    }
}
