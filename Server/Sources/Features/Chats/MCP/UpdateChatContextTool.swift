import Foundation

struct UpdateChatContextTool: MCPToolDefinition {
    private let repository: any ChatRepository

    init(repository: any ChatRepository) {
        self.repository = repository
    }

    let name = "whatsapp_update_chat_context"
    let icon = "text.bubble"
    let description = """
    Saves durable context about a specific chat, such as who that person/group is, the relationship to the client, and stable communication guidance.

    This tool updates only the chatContext field of the chat record.
    """
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "chatId": .object(["type": .string("string")]),
            "context": .object(["type": .string("string")])
        ]),
        "required": .array([.string("chatId"), .string("context")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "chatId", value: .string("chat-rene")),
        .init(name: "context", value: .string("Rene is the client's cousin. Prefer a warm but direct tone. Avoid sending long WhatsApp messages and reveal details progressively instead of dumping everything at once."))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let chatId = try MCPSupport.string("chatId", from: call)
        let contextText = try MCPSupport.string("context", from: call)

        guard let chat = try await repository.getChat(id: chatId) else {
            throw MCPServerError.invalidArguments("Chat '\(chatId)' was not found.")
        }

        try await repository.updateChatContext(chatId: chatId, context: contextText)

        return .object([
            "chatId": .string(chatId),
            "title": .string(chat.title),
            "chatContext": .string(contextText),
            "updated": .bool(true)
        ])
    }
}
