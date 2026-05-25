import Foundation

struct SearchSensitiveDataTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "search_sensitive_data",
        summary: "Search sensitive data items.",
        group: .sensitiveData,
        traits: [.readOnly]
    )

    init() {}
}
