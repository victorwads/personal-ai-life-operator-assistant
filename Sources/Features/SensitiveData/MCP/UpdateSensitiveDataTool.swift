import Foundation

struct UpdateSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "update_sensitive_data",
        summary: "Update a sensitive data item.",
        group: .sensitiveData,
        traits: [.writesState]
    )

    init() {}
}
