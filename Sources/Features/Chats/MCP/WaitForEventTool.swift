import Foundation

struct WaitForEventTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "wait_for_event",
        summary: "Wait for the next assistant event.",
        group: .chats,
        traits: [.blocking]
    )

    init() {}
}
