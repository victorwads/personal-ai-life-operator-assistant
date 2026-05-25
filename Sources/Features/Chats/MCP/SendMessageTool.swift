import Foundation

struct SendMessageTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "send_message",
        summary: "Send messages to a chat.",
        group: .chats,
        traits: [.writesState, .sideEffect]
    )

    init() {}
}
