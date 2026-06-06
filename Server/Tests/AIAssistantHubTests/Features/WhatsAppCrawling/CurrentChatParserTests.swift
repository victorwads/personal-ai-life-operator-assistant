import XCTest
@testable import AIAssistantHub

final class CurrentChatParserTests: XCTestCase {
    func testDetectMessageKindUsesImagesSchemaVersion3() {
        let kind = WhatsAppCrawlingNormalizer.detectMessageKind(rawMessage: [
            "images": [
                [
                    "found": elementHandle(id: "image-1")
                ],
                [
                    "found": elementHandle(id: "image-2")
                ]
            ]
        ])

        XCTAssertEqual(kind, .image)
    }

    func testDetectMessageKindUsesStickersSchemaVersion3() {
        let kind = WhatsAppCrawlingNormalizer.detectMessageKind(rawMessage: [
            "stickers": [
                [
                    "found": elementHandle(id: "sticker-1")
                ],
                [
                    "found": elementHandle(id: "sticker-2")
                ]
            ]
        ])

        XCTAssertEqual(kind, .sticker)
    }

    func testDetectMessageKindReturnsTextWhenNoMediaSchemaIsPresent() {
        let kind = WhatsAppCrawlingNormalizer.detectMessageKind(rawMessage: [
            "messageText": "Hello"
        ])

        XCTAssertEqual(kind, .text)
    }

    func testParseStoresMultipleImageCandidatesForOneMessage() throws {
        let parsed = try XCTUnwrap(WhatsAppCurrentChatParser.parse(from: fixtureRootWithMessage(imagePayload: [
            "images": [
                [
                    "found": elementHandle(id: "image-1")
                ],
                [
                    "found": elementHandle(id: "image-2")
                ]
            ]
        ])))

        XCTAssertEqual(parsed.mediaElementsByMessageId["whatsapp-message-1"]?.map(\.id), ["image-1", "image-2"])
    }

    func testParseStoresMultipleStickerCandidatesForOneMessage() throws {
        let parsed = try XCTUnwrap(WhatsAppCurrentChatParser.parse(from: fixtureRootWithMessage(stickerPayload: [
            "stickers": [
                [
                    "found": elementHandle(id: "sticker-1")
                ],
                [
                    "found": elementHandle(id: "sticker-2")
                ]
            ]
        ])))

        XCTAssertEqual(parsed.mediaElementsByMessageId["whatsapp-message-1"]?.map(\.id), ["sticker-1", "sticker-2"])
    }

    func testParseIgnoresMessagesWithoutMediaArrays() throws {
        let parsed = try XCTUnwrap(WhatsAppCurrentChatParser.parse(from: fixtureRootWithMessage()))

        XCTAssertNil(parsed.mediaElementsByMessageId["whatsapp-message-1"])
    }

    private func fixtureRootWithMessage(imagePayload: [String: Any] = [:], stickerPayload: [String: Any] = [:]) -> [String: Any] {
        var message: [String: Any] = [
            "messageId": "message-1",
            "messageDatetimeAndAuthor": "[12:00, 01/01/2026] Alice:",
            "messageAuthor": "Alice",
            "messageTime": "12:00",
            "messageText": "Hello",
            "sent": true
        ]
        for (key, value) in imagePayload {
            message[key] = value
        }
        for (key, value) in stickerPayload {
            message[key] = value
        }

        return [
            "web": [
                "currentChat": [
                    "chatTitle": "Test Chat",
                    "chatMessages": [message]
                ]
            ]
        ]
    }

    private func elementHandle(id: String) -> [String: Any] {
        ["$element": true, "id": id]
    }
}
