import AppKit
import XCTest
@testable import Passst

@MainActor
final class ClipboardPayloadTests: XCTestCase {
    func testTextRoundTripThroughPasteboard() throws {
        let pasteboard = NSPasteboard(name: .init("app.passst.tests.\(UUID().uuidString)"))
        let codec = PasteboardCodec()
        let original = ClipboardPayload.text("Café, clipboard")

        _ = try codec.write(original, to: pasteboard)
        let captured = try codec.capture(from: pasteboard)

        XCTAssertEqual(captured.plainText, "Café, clipboard")
        XCTAssertEqual(
            captured.items.first?.representation(for: .string)?.data,
            Data("Café, clipboard".utf8)
        )
    }

    func testDigestIsStableAcrossRepresentationOrdering() {
        let text = PasteboardRepresentation(type: .string, data: Data("Value".utf8))
        let html = PasteboardRepresentation(
            type: .html,
            data: Data("<b>Value</b>".utf8)
        )
        let first = ClipboardPayload(
            items: [ClipboardPayloadItem(representations: [text, html])],
            plainText: "Value"
        )
        let second = ClipboardPayload(
            items: [ClipboardPayloadItem(representations: [html, text])],
            plainText: "Value"
        )

        XCTAssertEqual(first.stableDigest, second.stableDigest)
    }

    func testConcealedPayloadIsIgnored() {
        let pasteboard = NSPasteboard(name: .init("app.passst.tests.\(UUID().uuidString)"))
        let item = NSPasteboardItem()
        item.setString(
            "secret",
            forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        )
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        XCTAssertThrowsError(try PasteboardCodec().capture(from: pasteboard)) { error in
            guard case PasteboardCodec.CodecError.concealedContent = error else {
                return XCTFail("Expected concealedContent, got \(error)")
            }
        }
    }

    func testClassifiesLinkColorAndFiles() {
        XCTAssertEqual(
            ClipboardPayloadClassifier.kind(for: .text("https://pasteapp.io/help")),
            .link
        )
        XCTAssertEqual(
            ClipboardPayloadClassifier.kind(for: .text("#5A67D8")),
            .color
        )

        let url = URL(fileURLWithPath: "/tmp/Document.pdf")
        let files = ClipboardPayload(
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
            plainText: url.path,
            fileURLs: [url]
        )
        XCTAssertEqual(ClipboardPayloadClassifier.kind(for: files), .files)
    }

    func testClassifiesSourceCodeWithoutTreatingProseAsCode() {
        XCTAssertEqual(
            ClipboardPayloadClassifier.kind(
                for: .text(
                    """
                    struct ClipboardItem {
                        let value: String
                    }
                    """
                )
            ),
            .code
        )
        XCTAssertEqual(
            ClipboardPayloadClassifier.kind(
                for: .text("Ordinary text with several words")
            ),
            .text
        )
    }

    func testImageRepresentationWinsOverImageFileURLFallback() {
        let url = URL(fileURLWithPath: "/tmp/telegram-photo.jpg")
        let payload = ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(
                            type: .fileURL,
                            data: Data(url.absoluteString.utf8)
                        )
                    ]
                ),
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(
                            type: .tiff,
                            data: Data([0x49, 0x49, 0x2A, 0x00])
                        )
                    ]
                )
            ],
            plainText: url.lastPathComponent,
            fileURLs: [url]
        )

        XCTAssertEqual(ClipboardPayloadClassifier.kind(for: payload), .image)
    }

    func testImageRepresentationSupportsGenericImageUTIs() {
        let payload = ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(
                            typeIdentifier: "public.jpeg",
                            data: Data([0xFF, 0xD8, 0xFF])
                        ),
                        PasteboardRepresentation(
                            type: .string,
                            data: Data("photo.jpg".utf8)
                        )
                    ]
                )
            ],
            plainText: "photo.jpg"
        )

        XCTAssertEqual(ClipboardPayloadClassifier.kind(for: payload), .image)
        XCTAssertEqual(
            ClipboardPayloadClassifier.makeRecord(
                for: payload,
                sourceBundleIdentifier: nil,
                sourceApplicationName: nil
            ).displayTitle,
            "photo.jpg"
        )
    }

    func testMultipleFilesUseTheirNamesInTheCardHeader() {
        let first = URL(fileURLWithPath: "/tmp/Quarterly Report.pdf")
        let second = URL(fileURLWithPath: "/tmp/Budget.xlsx")
        let payload = ClipboardPayload(
            items: [],
            plainText: nil,
            fileURLs: [first, second]
        )

        let record = ClipboardPayloadClassifier.makeRecord(
            for: payload,
            sourceBundleIdentifier: nil,
            sourceApplicationName: nil
        )

        XCTAssertEqual(record.displayTitle, "Quarterly Report.pdf +1")
    }

    func testCaptureAddsPortablePNGForGenericImageRepresentation() throws {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        let jpeg = try XCTUnwrap(
            bitmap?.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        )
        let pasteboard = NSPasteboard(name: .init("app.passst.tests.\(UUID().uuidString)"))
        let item = NSPasteboardItem()
        item.setData(jpeg, forType: .init("public.jpeg"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])

        let payload = try PasteboardCodec().capture(from: pasteboard)

        XCTAssertNotNil(payload.representationData(for: .png))
        XCTAssertEqual(ClipboardPayloadClassifier.kind(for: payload), .image)
    }

    func testExtractsWebImageURLFromCopiedHTML() {
        let html = """
        <a href="https://youtube.com/watch?v=abc">
          <img src="https://i.ytimg.com/vi/abc/hqdefault.jpg?a=1&amp;b=2">
        </a>
        """
        let payload = ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(type: .html, data: Data(html.utf8))
                    ]
                )
            ]
        )

        XCTAssertEqual(
            payload.referencedWebImageURL?.absoluteString,
            "https://i.ytimg.com/vi/abc/hqdefault.jpg?a=1&b=2"
        )
    }

    func testImageWithNonImageFileRemainsMixed() {
        let url = URL(fileURLWithPath: "/tmp/document.pdf")
        let payload = ClipboardPayload(
            items: [
                ClipboardPayloadItem(
                    representations: [
                        PasteboardRepresentation(type: .tiff, data: Data([0x49, 0x49])),
                        PasteboardRepresentation(
                            type: .fileURL,
                            data: Data(url.absoluteString.utf8)
                        )
                    ]
                )
            ],
            fileURLs: [url]
        )

        XCTAssertEqual(ClipboardPayloadClassifier.kind(for: payload), .mixed)
    }
}
