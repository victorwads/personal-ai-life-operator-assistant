import Foundation

struct WaitNextEventTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "wait_next_event",
        summary: "Wait for the next event occurrence.",
        group: .chats,
        traits: [.blocking]
    )

    init() {}
}
