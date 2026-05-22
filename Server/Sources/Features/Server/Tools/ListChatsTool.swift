import Foundation

struct ListChatsTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_chats",
        icon: "list.bullet",
        description: "Lists relevant chats from WhatsApp.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "limit": .object(["type": .string("number")])
            ])
        ],
        exampleParameters: [
            .init(name: "limit", value: .number(10))
        ],
        traits: [.readOnly]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let arguments = MCPToolArguments(values: call.arguments)
        let limit = arguments.int(for: "limit").map { max(1, $0) }
        let chats = await MainActor.run {
            context.memoryStore.conversations
                .filter { !context.isBlocked($0.name) }
                .prefix(limit ?? .max)
                .map(context.conversationJSONValue)
        }
        return .success(.object(["chats": .array(chats)]))
    }
}
