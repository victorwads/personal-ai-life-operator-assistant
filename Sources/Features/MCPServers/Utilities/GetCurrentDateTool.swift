import Foundation

struct GetCurrentDateTool: MCPToolDefinition {
    let name = "get_current_date"
    let icon = "calendar"
    let description = "Returns today's local date and current timestamp so the assistant can reference the present day."
    let group = "utilities"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.readOnly]
}
