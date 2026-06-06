import Foundation
import XCTest
@testable import AIAssistantHub

final class ChatMessagesReadReceiptTests: XCTestCase {
    func testEncodeAndDecodeRoundTrip() throws {
        let token = try ChatMessagesReadReceiptCoder.encode(
            chatId: "some-chat-id",
            lastChatMessageId: "some-last-message-id"
        )

        XCTAssertEqual(
            token,
            Data("some-chat-id|some-last-message-id".utf8).base64EncodedString()
        )

        XCTAssertEqual(
            try ChatMessagesReadReceiptCoder.decode(token),
            ChatMessagesReadReceipt(
                chatId: "some-chat-id",
                lastChatMessageId: "some-last-message-id"
            )
        )
    }

    func testDecodeThrowsForInvalidToken() {
        XCTAssertThrowsError(try ChatMessagesReadReceiptCoder.decode("not-base64")) { error in
            XCTAssertEqual(error.localizedDescription, "Invalid chat read receipt token. Expected a base64-encoded 'chatId|lastChatMessageId' string.")
        }
    }
}
