import Foundation

struct ListSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_sensitive_data",
        summary: "List sensitive data items.",
        group: .sensitiveData,
        traits: [.readOnly]
    )

    init() {}
}
