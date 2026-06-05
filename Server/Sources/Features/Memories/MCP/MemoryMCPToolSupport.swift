import Foundation

enum MemoryMCPToolSupport {
    static func memoryObject(_ memory: Memory) -> MCPJSONValue {
        .object([
            "id": memory.id.map(MCPJSONValue.string) ?? .null,
            "key": .string(memory.key),
            "value": .string(memory.value)
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
