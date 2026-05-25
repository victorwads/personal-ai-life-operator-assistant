import Foundation

struct DeleteSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "delete_sensitive_data",
        summary: "Delete a sensitive data item.",
        group: .sensitiveData,
        traits: [.writesState]
    )

    init() {}
}
