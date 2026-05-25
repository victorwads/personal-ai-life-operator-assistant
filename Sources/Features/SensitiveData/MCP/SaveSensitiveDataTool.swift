import Foundation

struct SaveSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "save_sensitive_data",
        summary: "Store sensitive or delicate reusable data.",
        group: .sensitiveData,
        traits: [.writesState]
    )

    init() {}
}
