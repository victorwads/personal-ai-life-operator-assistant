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
}

enum MemoryMCPToolError: Error, MCPServerErrorProviding {
    case invalidArguments(String)

    var serverError: MCPServerError {
        switch self {
        case .invalidArguments(let message):
            return .invalidArguments(message)
        }
    }
}
