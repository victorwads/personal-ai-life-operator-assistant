import Foundation

protocol MCPToolCallValidator: Sendable {
    var name: String { get }

    func validate(
        call: MCPToolCall,
        definition: any MCPToolDefinition,
        context: MCPToolValidationContext
    ) async -> MCPToolValidationResult
}
