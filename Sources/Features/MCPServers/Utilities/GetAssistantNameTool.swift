import Foundation

struct GetAssistantNameTool: MCPToolDefinition {
    let name = "get_assistant_name"
    let icon = "person.crop.circle"
    let description = "Returns the configured assistant name used to introduce the assistant and prefix outgoing messages."
    let group = "utilities"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.readOnly]
}
