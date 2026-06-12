import Foundation
import XCTest
@testable import AIAssistantHub

@MainActor
final class WhatsAppChatCrawlingOrchestratorAITextTests: XCTestCase {
    func testEnrichMessageTextWithAIStoresReturnedTextAndKeepsLocalMediaPaths() async throws {
        let relativePath = try saveMediaFixture(filename: "enrichment-success.png")
        let extractor = StubAIImageExtractor(behavior: .success("  AI extracted text  "))
        let orchestrator = makeOrchestrator(aiImageExtractor: extractor)

        var messages = [
            ChatMessage(
                id: "message-1",
                chatId: "chat-1",
                author: nil,
                text: nil,
                kind: .image,
                direction: .received,
                listOrder: 0,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                localMediaPaths: [relativePath]
            )
        ]

        await orchestrator.enrichMessageTextWithAI(
            messageIndex: 0,
            messageId: "message-1",
            mediaKind: .image,
            relativePaths: [relativePath],
            in: &messages
        )

        XCTAssertEqual(messages[0].text, "AI extracted text")
        XCTAssertEqual(messages[0].imageExtractionFailed, false)
        XCTAssertEqual(messages[0].localMediaPaths, [relativePath])
        XCTAssertEqual(extractor.receivedImageURLs, [ChatMediaStorage.absoluteURL(forRelativePath: relativePath)])
    }

    func testEnrichMessageTextWithAIFailureLeavesMediaPathsUntouched() async throws {
        let relativePath = try saveMediaFixture(filename: "enrichment-failure.png")
        let extractor = StubAIImageExtractor(behavior: .failure)
        let orchestrator = makeOrchestrator(aiImageExtractor: extractor)

        var messages = [
            ChatMessage(
                id: "message-2",
                chatId: "chat-1",
                author: nil,
                text: nil,
                kind: .sticker,
                direction: .received,
                listOrder: 0,
                dateTime: nil,
                quotedMessageText: nil,
                quotedMessageAuthor: nil,
                localMediaPaths: [relativePath]
            )
        ]

        await orchestrator.enrichMessageTextWithAI(
            messageIndex: 0,
            messageId: "message-2",
            mediaKind: .sticker,
            relativePaths: [relativePath],
            in: &messages
        )

        XCTAssertNil(messages[0].text)
        XCTAssertEqual(messages[0].imageExtractionFailed, true)
        XCTAssertEqual(messages[0].localMediaPaths, [relativePath])
        XCTAssertEqual(extractor.receivedImageURLs, [ChatMediaStorage.absoluteURL(forRelativePath: relativePath)])
    }

    private func makeOrchestrator(aiImageExtractor: any AIImageExtracting) -> WhatsAppChatCrawlingOrchestrator {
        let repository = StubChatRepository()
        let settings = SettingsStore(
            profileId: "profile-ai-text",
            repository: InMemorySettingsRepository()
        )
        let clientVoiceSettings = ClientVoiceSettingsWrapper(settings: settings)
        return WhatsAppChatCrawlingOrchestrator(
            profileId: "profile-ai-text",
            chatRepositoryProvider: { repository },
            permissionModeProvider: { .allowAllExceptDenied },
            aiImageExtractorProvider: { aiImageExtractor },
            audioTranscriptionServiceProvider: {
                WhatsAppAudioTranscriptionService(
                    profileId: "profile-ai-text",
                    settingsProvider: { clientVoiceSettings }
                )
            },
            yamlText: "{}",
            logStore: WhatsAppCrawlingLogStore(),
            sharedLocks: SharedLockRegistry()
        )
    }

    private func saveMediaFixture(filename: String) throws -> String {
        let data = Data(filename.utf8)
        let paths = try ChatMediaStorage.saveImageData(
            [ChatMediaImageData(data: data, mimeType: "image/png")],
            profileId: "profile-ai-text",
            forMessageId: "message-ai-text"
        )
        return try XCTUnwrap(paths.first)
    }
}

private enum StubError: Error {
    case unavailable
}

@MainActor
private final class StubAIImageExtractor: AIImageExtracting {
    enum Behavior {
        case success(String)
        case failure
    }

    let behavior: Behavior
    private(set) var receivedImageURLs: [URL] = []

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func extractTextAndDescription(from imageURLs: [URL], mediaKind _: ChatMessage.Kind) async throws -> String {
        receivedImageURLs = imageURLs
        switch behavior {
        case let .success(text):
            return text
        case .failure:
            throw StubError.unavailable
        }
    }
}

private final class StubChatRepository: ChatRepository {
    func getChat(id _: String) async throws -> Chat? { nil }
    func listChats() async throws -> [Chat] { [] }
    func upsertChat(_: Chat) async throws {}
    func updateChatContext(chatId _: String, context _: String) async throws {}
    func updateChatPermission(chatId _: String, permission _: ChatPermission?) async throws {}
    func deleteChat(id _: String) async throws {}
    func deleteAllChatsAndMessages() async throws {}
    func listUnhandledChats(limit _: Int?, permissionMode _: ChatPermissionMode) async throws -> [Chat] { [] }
    func listMessages(chatId _: String, limit _: Int?) async throws -> [ChatMessage] { [] }
    func listUnhandledMessages(chatId _: String, limit _: Int?) async throws -> [ChatMessage] { [] }
    func insertMessages(_ messages: [ChatMessage]) async throws -> [ChatMessage] { messages }
    func markMessagesHandled(ids _: [String]) async throws {}
    func setMessageHandled(chatId _: String, messageId _: String, handled _: Bool) async throws {}
    func setMessagesHandled(chatId _: String, messageIds _: [String], handled _: Bool) async throws -> Int { 0 }
    func markAllMessagesHandled(chatId _: String) async throws -> Int { 0 }
    func markAllUnhandledMessagesHandled() async throws -> Int { 0 }
    func markMessagesHandledThrough(chatId _: String, lastChatMessageId _: String) async throws -> Int { 0 }
    func markMessagesUnhandledFrom(chatId _: String, firstChatMessageId _: String) async throws -> Int { 0 }
    func observeMessages(chatId _: String, onChange _: @escaping @Sendable () -> Void) -> FirestoreListenerToken {
        FirestoreListenerToken {}
    }
    func existingMessageIds(chatId _: String) async throws -> Set<String> { [] }
    func deleteMessage(id _: String) async throws {}
    func deleteChatMessages(chatId _: String) async throws {}
    func deleteChatAndMessages(chatId _: String) async throws {}
    func countUnhandledMessages(chatId _: String) async throws -> Int { 0 }
    func updateUnhandledCount(chatId _: String, count _: Int?) async throws {}
    func setMessageSentByAssistant(chatId _: String, messageId _: String, sentByAssistant _: Bool) async throws {}
    func setMessageImageExtractionFailed(chatId _: String, messageId _: String, failed _: Bool) async throws {}
    func setMessageImageExtractionResult(chatId _: String, messageId _: String, text _: String?) async throws {}
}

@MainActor
private final class InMemorySettingsRepository: SettingsRepository {
    private var documents: [String: [String: String]] = [:]

    func loadAllScopes() async throws -> [SettingsDocument] {
        documents.map { SettingsDocument(scopeName: $0.key, values: $0.value) }
    }

    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        SettingsDocument(scopeName: scopeName, values: documents[scopeName] ?? [:])
    }

    func saveScope(_ scopeName: String, values: [String: String]) async throws {
        documents[scopeName] = values
    }

    func getValue(scopeName: String, key: String) async throws -> String? {
        documents[scopeName]?[key]
    }

    func setValue(scopeName: String, key: String, value: String) async throws {
        var values = documents[scopeName] ?? [:]
        values[key] = value
        documents[scopeName] = values
    }

    func deleteValue(scopeName: String, key: String) async throws {
        var values = documents[scopeName] ?? [:]
        values.removeValue(forKey: key)
        documents[scopeName] = values
    }

    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        listener(SettingsDocument(scopeName: scopeName, values: documents[scopeName] ?? [:]))
        return FirestoreListenerToken {}
    }

    func observeAllScopes(_ onChange: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        onChange(documents.map { SettingsDocument(scopeName: $0.key, values: $0.value) })
        return FirestoreListenerToken {}
    }
}
