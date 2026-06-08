import XCTest
@testable import AIAssistantHub

final class WhatsAppAudioMediaAssignerTests: XCTestCase {
    func testAssignAudioMediaMapsByVisibleOrderAndMessageId() throws {
        let profileId = "profile-audio-assignment"
        let messages = [
            makeAudioMessage(id: "message-1"),
            makeAudioMessage(id: "message-2"),
            makeAudioMessage(id: "message-3")
        ]
        let capturedAudio = [
            makeCapturedMedia(base64: Data("blob-0".utf8).base64EncodedString()),
            makeCapturedMedia(base64: Data("blob-1".utf8).base64EncodedString()),
            makeCapturedMedia(base64: Data("blob-2".utf8).base64EncodedString())
        ]

        cleanup(profileId: profileId, messageIds: ["message-1", "message-2", "message-3"])
        let assigned = try WhatsAppAudioMediaAssigner.assignAudioMedia(
            to: messages,
            capturedAudio: capturedAudio,
            profileId: profileId,
            log: { _ in }
        )

        XCTAssertEqual(assigned[0].localMediaPaths, ["Profiles/\(profileId)/Media/message-1/d3320f39a090ec89d4b69364211d91ae.ogg"])
        XCTAssertEqual(assigned[1].localMediaPaths, ["Profiles/\(profileId)/Media/message-2/f20237f5f45ec9d7469ecc19e4eb0afc.ogg"])
        XCTAssertEqual(assigned[2].localMediaPaths, ["Profiles/\(profileId)/Media/message-3/cd3f8f515e076480036a397e70460ebb.ogg"])
    }

    func testAssignAudioMediaSkipsWhenCountsDiffer() throws {
        let profileId = "profile-audio-mismatch"
        let messages = [
            makeAudioMessage(id: "message-1"),
            makeAudioMessage(id: "message-2")
        ]
        let capturedAudio = [
            makeCapturedMedia(base64: Data("blob-only".utf8).base64EncodedString())
        ]

        cleanup(profileId: profileId, messageIds: ["message-1", "message-2"])
        let assigned = try WhatsAppAudioMediaAssigner.assignAudioMedia(
            to: messages,
            capturedAudio: capturedAudio,
            profileId: profileId,
            log: { _ in }
        )

        XCTAssertTrue(assigned.allSatisfy { $0.localMediaPaths.isEmpty })
        XCTAssertFalse(FileManager.default.fileExists(atPath: ChatMediaStorage.absoluteURL(forRelativePath: "Profiles/\(profileId)/Media/message-1").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ChatMediaStorage.absoluteURL(forRelativePath: "Profiles/\(profileId)/Media/message-2").path))
    }

    private func makeAudioMessage(id: String) -> ChatMessage {
        ChatMessage(
            id: id,
            chatId: "chat-1",
            author: nil,
            text: nil,
            kind: .audio,
            direction: .received,
            listOrder: 0,
            dateTime: nil,
            quotedMessageText: nil,
            quotedMessageAuthor: nil,
            localMediaPaths: []
        )
    }

    private func makeCapturedMedia(base64: String) -> WebViewCapturedMedia {
        WebViewCapturedMedia(
            mimeType: "audio/ogg; codecs=opus",
            size: 1,
            timestamp: 1,
            base64: base64
        )
    }

    private func cleanup(profileId: String, messageIds: [String]) {
        for messageId in messageIds {
            let directoryURL = ChatMediaStorage.absoluteURL(forRelativePath: "Profiles/\(profileId)/Media/\(messageId)")
            if FileManager.default.fileExists(atPath: directoryURL.path) {
                try? FileManager.default.removeItem(at: directoryURL)
            }
        }
    }
}
