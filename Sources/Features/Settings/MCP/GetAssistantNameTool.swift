import Foundation

struct GetAssistantNameTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_assistant_name",
        summary: "Return the assistant name configured by the app.",
        group: .utilities,
        traits: [.readOnly]
    )

    init() {}
}
