import Foundation

struct ListChatsTool: MCPToolDefinition {
    private let repository: any ChatRepository
    private let permissionModeProvider: @MainActor () -> ChatPermissionMode

    init(
        repository: any ChatRepository,
        permissionModeProvider: @escaping @MainActor () -> ChatPermissionMode
    ) {
        self.repository = repository
        self.permissionModeProvider = permissionModeProvider
    }

    let name = "list_chats"
    let icon = "text.bubble"
    let description = "Lists persisted chats from the local chat store."
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "limit": .object(["type": .string("number")])
        ])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "limit", value: .integer(5))
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let limit = MCPSupport.optionalLimit(from: call, default: 5)
        let mode = await permissionModeProvider()
        let chats = try await repository.listChats()
            .filter { ChatPermissionResolver.isChatAllowed($0, mode: mode) }

        return .object([
            "count": .int(min(chats.count, limit)),
            "chats": .array(Array(chats.prefix(limit)).map(chatJSON))
        ])
    }

    private func chatJSON(_ chat: Chat) -> MCPJSONValue {
        .object([
            "chatId": chat.id.map(MCPJSONValue.string) ?? .string(""),
            "title": .string(chat.title),
            "lastMessagePreview": chat.lastMessagePreview.map(MCPJSONValue.string) ?? .null,
            "lastMessageTimeText": chat.lastMessageTimeText.map(MCPJSONValue.string) ?? .null,
            "unreadCount": .int(chat.unreadCount),
            "unhandledCount": .int(chat.unhandledCount)
        ])
    }
}
