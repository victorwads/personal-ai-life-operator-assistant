import Foundation

struct GetCurrentDateTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_current_date",
        icon: "calendar",
        description: "Returns today's local date and current timestamp so the assistant can reference the present day.",
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
