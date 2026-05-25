import Foundation

protocol MCPToolHandler {
    static var definition: MCPToolDefinition { get }
    init()

    func handle(_ call: MCPToolCall, context: MCPServerContext) async -> MCPToolExecutionResult
}

extension MCPToolHandler {
    func handle(_ call: MCPToolCall, context: MCPServerContext) async -> MCPToolExecutionResult {
        .failure(toolName: Self.definition.name, error: .notImplemented("Tool handler not implemented yet."))
    }
}
