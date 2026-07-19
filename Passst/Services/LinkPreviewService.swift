import AppKit
import Foundation
import ImageIO
@preconcurrency import LinkPresentation
import OSLog
import UniformTypeIdentifiers

struct LinkPreviewData: Sendable {
    let url: URL
    let title: String
    let image: CGImage?

    var domain: String {
        url.host(percentEncoded: false) ?? url.host() ?? url.absoluteString
    }
}

@MainActor
final class LinkPreviewService {
    static let shared = LinkPreviewService()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app.passst.mac",
        category: "LinkPreview"
    )

    private var cache: [URL: LinkPreviewData] = [:]
    private var failedAt: [URL: Date] = [:]
    private var activeProviders: [UUID: LPMetadataProvider] = [:]
    private let failureRetryInterval: TimeInterval = 30

    private init() {}

    func preview(for rawURL: String) async -> LinkPreviewData? {
        guard let url = normalizedWebURL(from: rawURL) else {
            return nil
        }
        if let cached = cache[url] {
            return cached
        }
        if let failureDate = failedAt[url],
           Date().timeIntervalSince(failureDate) < failureRetryInterval {
            return nil
        }

        let provider = LPMetadataProvider()
        provider.timeout = 8
        provider.shouldFetchSubresources = true
        let requestID = UUID()
        activeProviders[requestID] = provider
        defer {
            activeProviders[requestID] = nil
        }

        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            guard !Task.isCancelled else {
                provider.cancel()
                return nil
            }

            let imageData = await Self.loadImageData(
                from: metadata.imageProvider ?? metadata.iconProvider
            )
            let image = await Self.decodeImage(imageData)
            let resolvedURL = normalizedWebURL(
                from: metadata.originalURL?.absoluteString
                    ?? metadata.url?.absoluteString
                    ?? url.absoluteString
            ) ?? url
            let title = metadata.title?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let preview = LinkPreviewData(
                url: resolvedURL,
                title: title.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle(for: url),
                image: image
            )
            cache[url] = preview
            failedAt[url] = nil
            return preview
        } catch is CancellationError {
            provider.cancel()
            return nil
        } catch {
            failedAt[url] = Date()
            Self.logger.debug(
                "Link preview unavailable for \(url.host() ?? "unknown", privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func normalizedWebURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil
        else {
            return nil
        }
        components.fragment = nil
        return components.url
    }

    private func fallbackTitle(for url: URL) -> String {
        url.host(percentEncoded: false) ?? url.host() ?? "Link"
    }

    private static func loadImageData(from provider: NSItemProvider?) async -> Data? {
        guard let provider,
              let typeIdentifier = provider.registeredTypeIdentifiers.first(where: {
                  UTType($0)?.conforms(to: .image) == true
              })
        else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func decodeImage(_ data: Data?) async -> CGImage? {
        await Task.detached(priority: .utility) {
            guard let data,
                  let source = CGImageSourceCreateWithData(data as CFData, nil)
            else {
                return nil
            }
            return CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            )
        }.value
    }
}
