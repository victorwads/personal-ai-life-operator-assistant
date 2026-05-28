import Foundation

struct GetAssistantNameTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_assistant_name",
        icon: "person.crop.circle",
        description: "Returns the configured assistant name used to introduce the assistant and prefix outgoing messages.",
        group: .utilities,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ]),
        exampleParameters: [],
        traits: [.readOnly]
    )

    init() {}
}
