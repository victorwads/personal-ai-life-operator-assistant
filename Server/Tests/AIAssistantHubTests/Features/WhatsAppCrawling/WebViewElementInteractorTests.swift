import XCTest
@testable import AIAssistantHub

final class WebViewElementInteractorTests: XCTestCase {
    func testExtractedImageFromRejectsBoundsOnlyRecord() {
        let value: [String: Any] = [
            "x": 12,
            "y": 34,
            "width": 256,
            "height": 256
        ]

        XCTAssertNil(WebViewExtractedImage.from(value))
    }

    func testExtractedImageFromAcceptsSourceBasedRecord() {
        let value: [String: Any] = [
            "width": 256,
            "height": 256,
            "source": "https://example.com/image.png"
        ]

        let extracted = try? XCTUnwrap(WebViewExtractedImage.from(value))
        XCTAssertEqual(extracted?.source, "https://example.com/image.png")
        XCTAssertEqual(extracted?.width, 256)
        XCTAssertEqual(extracted?.height, 256)
    }

    func testExtractedImageFromAcceptsBase64Record() {
        let value: [String: Any] = [
            "base64": "aGVsbG8=",
            "mimeType": "image/png",
            "width": 10,
            "height": 10
        ]

        let extracted = try? XCTUnwrap(WebViewExtractedImage.from(value))
        XCTAssertEqual(extracted?.base64, "aGVsbG8=")
        XCTAssertEqual(extracted?.mimeType, "image/png")
        XCTAssertEqual(extracted?.width, 10)
        XCTAssertEqual(extracted?.height, 10)
    }
}
