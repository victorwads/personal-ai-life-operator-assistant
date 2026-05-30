import Foundation

enum MemoryMCPToolSupport {
    static func repository(
        explicit repository: FirestoreMemoryRepository?,
        context: MCPServerContext
    ) -> FirestoreMemoryRepository? {
        if let repository {
            return repository
        }

        guard let profileId = context.userInfo["profileId"]?.trimmedNonEmpty else {
            return nil
        }

        return FirestoreMemoryRepository(scope: FirebaseProfileScope(profileId: profileId))
    }

    static func requiredString(
        _ name: String,
        from call: MCPToolCall
    ) throws -> String {
        guard let value = call.arguments[name]?.stringValue?.trimmedNonEmpty else {
            throw MemoryMCPToolError.invalidArguments("Missing required argument `\(name)`.")
        }
        return value
    }

    static func optionalString(
        _ name: String,
        from call: MCPToolCall
    ) -> String? {
        call.arguments[name]?.stringValue?.trimmedNonEmpty
    }

    static func optionalLimit(
        from call: MCPToolCall,
        default defaultValue: Int
    ) -> Int {
        guard let value = call.arguments["limit"]?.intValue else {
            return defaultValue
        }
        return max(1, value)
    }

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
        if let toolError = error as? MemoryMCPToolError {
            return .failure(toolName: toolName, error: toolError.serverError)
        }
        return .failure(toolName: toolName, error: .executionFailed(error.localizedDescription))
    }
}

enum MemoryMCPToolError: Error {
    case invalidArguments(String)
    case repositoryUnavailable

    var serverError: MCPServerError {
        switch self {
        case .invalidArguments(let message):
            return .invalidArguments(message)
        case .repositoryUnavailable:
            return .executionFailed("Memories repository is unavailable for this MCP context.")
        }
    }
}

private extension MCPJSONValue {
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        case .string(let value):
            return Int(value)
        default:
            return nil
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
