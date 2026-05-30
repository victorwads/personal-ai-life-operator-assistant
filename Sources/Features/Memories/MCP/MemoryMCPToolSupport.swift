import Foundation

enum MemoryMCPToolSupport {
    static func memoryObject(_ memory: Memory) -> MCPJSONValue {
        .object([
            "id": memory.id.map(MCPJSONValue.string) ?? .null,
            "key": .string(memory.key),
            "value": .string(memory.value)
        ])
    }

    static func memoryList(_ memories: [Memory]) -> MCPJSONValue {
        .object([
            "count": .integer(memories.count),
            "memories": .array(memories.map(memoryObject))
        ])
    }

    static func failure(
        toolName: String,
        _ error: Error
    ) -> MCPToolExecutionResult {
        if let argumentError = error as? MCPToolArgumentError {
            return .failure(toolName: toolName, error: argumentError.serverError)
        }
        if let toolError = error as? MemoryMCPToolError {
            return .failure(toolName: toolName, error: toolError.serverError)
        }
        return .failure(toolName: toolName, error: .executionFailed(error.localizedDescription))
    }
}

enum MemoryMCPToolError: Error {
    case invalidArguments(String)

    var serverError: MCPServerError {
        switch self {
        case .invalidArguments(let message):
            return .invalidArguments(message)
        }
    }
}
