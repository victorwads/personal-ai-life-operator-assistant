import XCTest

@testable import AssistantMCPServer

@MainActor
final class ListChatsToolTests: XCTestCase {
    func test_listChats_respectsIsBlocked() async throws {
        let defaults = TestContextFactory.makeDefaults()
        let sendPrefixRepository = MCPSendPrefixRepository(defaults: defaults)
        let memoryStore = WhatsAppMemoryStore(sendPrefixRepository: sendPrefixRepository)

        memoryStore.replaceConversations([
            ConversationSummary(
                id: "chat-1",
                accessibilityPath: [],
                name: "Allowed Chat",
                unreadCount: 0,
                isPinned: false,
                isSelected: false,
                lastMessagePreview: nil,
                lastMessageAtText: nil,
                lastMessageDirection: .unknown,
                lastMessageStatus: .unknown,
                isTyping: false
            ),
            ConversationSummary(
                id: "chat-2",
                accessibilityPath: [],
                name: "Blocked Chat",
                unreadCount: 0,
                isPinned: false,
                isSelected: false,
                lastMessagePreview: nil,
                lastMessageAtText: nil,
                lastMessageDirection: .unknown,
                lastMessageStatus: .unknown,
                isTyping: false
            )
        ])

        let runtime = TestMCPRuntime()
        runtime.blockedConversationNames = ["Blocked Chat"]
        let context = TestContextFactory.makeServerContext(
            defaults: defaults,
            memoryStore: memoryStore,
            runtime: runtime
        )

        let result = await ListChatsTool.handle(
            MCPToolCall(name: "list_chats", arguments: [:]),
            context: context
        )

        let payload = try unwrapSuccess(result)
        let chats = try unwrapChats(payload)
        XCTAssertEqual(chats.count, 1)
        XCTAssertEqual(chats.first?["name"]?.stringValue, "Allowed Chat")
    }

    func test_listChats_appliesLimit() async throws {
        let defaults = TestContextFactory.makeDefaults()
        let sendPrefixRepository = MCPSendPrefixRepository(defaults: defaults)
        let memoryStore = WhatsAppMemoryStore(sendPrefixRepository: sendPrefixRepository)

        memoryStore.replaceConversations([
            ConversationSummary(
                id: "chat-1",
                accessibilityPath: [],
                name: "Chat 1",
                unreadCount: 0,
                isPinned: false,
                isSelected: false,
                lastMessagePreview: nil,
                lastMessageAtText: nil,
                lastMessageDirection: .unknown,
                lastMessageStatus: .unknown,
                isTyping: false
            ),
            ConversationSummary(
                id: "chat-2",
                accessibilityPath: [],
                name: "Chat 2",
                unreadCount: 0,
                isPinned: false,
                isSelected: false,
                lastMessagePreview: nil,
                lastMessageAtText: nil,
                lastMessageDirection: .unknown,
                lastMessageStatus: .unknown,
                isTyping: false
            )
        ])

        let runtime = TestMCPRuntime()
        let context = TestContextFactory.makeServerContext(
            defaults: defaults,
            memoryStore: memoryStore,
            runtime: runtime
        )

        let result = await ListChatsTool.handle(
            MCPToolCall(name: "list_chats", arguments: ["limit": .number(1)]),
            context: context
        )

        let payload = try unwrapSuccess(result)
        let chats = try unwrapChats(payload)
        XCTAssertEqual(chats.count, 1)
    }
}

private func unwrapSuccess(_ result: Result<JSONValue, Error>) throws -> [String: JSONValue] {
    switch result {
    case .success(let value):
        guard case .object(let object) = value else {
            throw XCTSkip("Expected JSON object response.")
        }
        return object
    case .failure(let error):
        throw error
    }
}

private func unwrapChats(_ payload: [String: JSONValue]) throws -> [[String: JSONValue]] {
    guard let chatsValue = payload["chats"] else {
        throw XCTSkip("Response missing chats.")
    }
    guard case .array(let array) = chatsValue else {
        throw XCTSkip("Response chats is not an array.")
    }
    return array.compactMap { element in
        guard case .object(let object) = element else { return nil }
        return object
    }
}
