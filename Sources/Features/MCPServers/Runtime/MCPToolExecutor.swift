import Foundation

final class MCPToolExecutor: MCPToolExecutionProviding {
    private let registry: MCPToolRegistry
    private let context: MCPServerContext

    init(registry: MCPToolRegistry, context: MCPServerContext = MCPServerContext()) {
        self.registry = registry
        self.context = context
    }

    func execute(_ call: MCPToolCall) async -> MCPToolExecutionResult {
        guard let definition = registry.definition(named: call.name) else {
            return .failure(toolName: call.name, error: .toolNotFound(call.name))
        }

        return await definition.execute(call, context: context)
    }
}
