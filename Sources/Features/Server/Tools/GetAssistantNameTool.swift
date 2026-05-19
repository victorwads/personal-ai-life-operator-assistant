import Foundation

struct GetAssistantNameTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_assistant_name",
        icon: "person.crop.circle",
        description: "Returns the configured assistant name used to introduce the assistant and prefix outgoing WhatsApp messages.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([:])
        ],
        exampleParameters: [],
        traits: [.readOnly]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let name = context.assistantName()
        return .success(.object([
            "name": .string(name),
            "isConfigured": .bool(!name.isEmpty)
        ]))
    }
}
