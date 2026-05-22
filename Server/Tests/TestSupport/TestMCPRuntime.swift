import Foundation

@testable import AssistantMCPServer

@MainActor
final class TestMCPRuntime: MCPServerRuntimeProviding {
    var blockedConversationNames: Set<String> = []

    func assistantName() -> String { "TestAssistant" }
    func speechLanguage() -> String { "pt-BR" }
    func speechVoiceIdentifier() -> String? { nil }
    func speechRate() -> Float { 0.5 }
    func formattedMCPSendMessages(for texts: [String]) -> [String] { texts }

    func refreshPendingClientAskCount() async {}
    func beginClientPromptWait() async -> UUID { UUID() }
    func endClientPromptWait(id: UUID) async {}
    func pendingClientPromptWaitCount() async -> Int { 0 }
    func submitClientPrompt(_ text: String) async {}
    func consumeClientPrompt() async -> String? { nil }

    func sendMessageViaScheduler(_ text: String, to conversationId: String) async throws {
        throw CancellationError()
    }

    func sendMessagesViaScheduler(_ texts: [String], to conversationId: String) async throws {
        throw CancellationError()
    }

    func ensureChatLoaded(chatId: String, reason: String) async {}

    func isBlocked(_ conversationName: String) -> Bool {
        blockedConversationNames.contains(conversationName)
    }

    func appendLog(_ message: String, level: LogLevel) {}
}
