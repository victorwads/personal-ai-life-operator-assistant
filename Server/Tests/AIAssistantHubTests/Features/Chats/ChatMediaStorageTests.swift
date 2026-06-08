import XCTest
@testable import AIAssistantHub

final class ChatMediaStorageTests: XCTestCase {
    func testSaveImageDataUsesMd5FilenameAndMimeExtension() throws {
        let profileId = "profile-media-md5"
        let messageId = "message-media-md5"
        try cleanup(profileId: profileId, messageId: messageId)

        let imageData = ChatMediaImageData(
            data: Data("hello".utf8),
            mimeType: "image/jpeg"
        )

        let paths = try ChatMediaStorage.saveImageData(
            [imageData],
            profileId: profileId,
            forMessageId: messageId
        )

        XCTAssertEqual(paths, ["Profiles/\(profileId)/Media/\(messageId)/5d41402abc4b2a76b9719d911017c592.jpg"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: ChatMediaStorage.absoluteURL(forRelativePath: paths[0]).path))
    }

    func testSaveImageDataPreservesOrderForDuplicatePayloads() throws {
        let profileId = "profile-media-dupes"
        let messageId = "message-media-dupes"
        try cleanup(profileId: profileId, messageId: messageId)

        let imageData = ChatMediaImageData(
            data: Data("duplicate".utf8),
            mimeType: "image/png"
        )

        let paths = try ChatMediaStorage.saveImageData(
            [imageData, imageData, imageData],
            profileId: profileId,
            forMessageId: messageId
        )

        XCTAssertEqual(paths.count, 3)
        XCTAssertEqual(Set(paths).count, 1)
        XCTAssertTrue(paths.allSatisfy { $0.contains("Profiles/\(profileId)/Media/\(messageId)/") })

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: ChatMediaStorage.absoluteURL(forRelativePath: "Profiles/\(profileId)/Media/\(messageId)"),
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(fileURLs.count, 1)
        XCTAssertTrue(fileURLs.first?.lastPathComponent.hasSuffix(".png") ?? false)
    }

    func testSaveAudioDataUsesMd5FilenameAndOggExtension() throws {
        let profileId = "profile-media-audio"
        let messageId = "message-media-audio"
        try cleanup(profileId: profileId, messageId: messageId)

        let audioData = ChatMediaData(
            data: Data("hello-audio".utf8),
            mimeType: "audio/ogg; codecs=opus"
        )

        let paths = try ChatMediaStorage.saveAudioData(
            [audioData],
            profileId: profileId,
            forMessageId: messageId
        )

        XCTAssertEqual(paths, ["Profiles/\(profileId)/Media/\(messageId)/6af581540154f7ca8db1e3d103c5d898.ogg"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: ChatMediaStorage.absoluteURL(forRelativePath: paths[0]).path))
    }

    private func cleanup(profileId: String, messageId: String) throws {
        let directoryURL = ChatMediaStorage.absoluteURL(forRelativePath: "Profiles/\(profileId)/Media/\(messageId)")
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.removeItem(at: directoryURL)
        }
    }
}
