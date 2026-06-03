import Foundation

protocol MCPToolDefinition {
    var name: String { get }
    var icon: String { get }
    var description: String { get }
    var group: String { get }
    var inputSchema: MCPJSONValue { get }
    var exampleParameters: [MCPToolExampleParameter] { get }
    var traits: [MCPToolTrait] { get }

    func execute(
        _ call: MCPToolCall,
        context: MCPServerContext
    ) async throws -> MCPJSONValue
}

extension MCPToolDefinition {
    var exampleParameters: [MCPToolExampleParameter] { [] }

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        throw MCPServerError.notImplemented("Tool definition not implemented yet.")
    }

    var jsonValue: MCPJSONValue {
        .object([
            "name": .string(name),
            "icon": .string(icon),
            "description": .string(description),
            "group": .string(group),
            "inputSchema": inputSchema,
            "exampleParameters": .array(exampleParameters.map(\.jsonValue)),
            "traits": .array(traits.map { .string($0.rawValue) })
        ])
    }
}
