import Foundation

struct AskToClientTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "ask_to_client",
        summary: "Ask the client for clarification or permission.",
        group: .clientVoice,
        traits: [.sideEffect, .blocking]
    )

    init() {}
}
