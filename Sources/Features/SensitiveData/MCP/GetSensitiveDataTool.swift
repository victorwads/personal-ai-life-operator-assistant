import Foundation

struct GetSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_sensitive_data",
        summary: "Fetch sensitive data with audit context.",
        group: .sensitiveData,
        traits: [.readOnly]
    )

    init() {}
}
