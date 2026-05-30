import Foundation

struct DeleteMemoryTool: MCPToolDefinition {
    private let repository: FirestoreMemoryRepository

    init(repository: FirestoreMemoryRepository) {
        self.repository = repository
    }

    let name = "delete_memory"
    let icon = "trash"
    let description = "Deletes a saved memory by `key` or `id`. Use this only when a memory is wrong, obsolete, duplicated, or should no longer guide future behavior."
    let group = "memories"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "id": .object(["type": .string("string")]),
            "key": .object(["type": .string("string")])
        ])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "key", value: .string("client_identity"))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async -> MCPToolExecutionResult {
        do {
            let id: String
            if let providedId = MCPToolArguments.optionalString("id", from: call) {
                id = providedId
            } else if
                let key = MCPToolArguments.optionalString("key", from: call),
                let memory = try await repository.query(
                    matching: ["key": key],
                    limit: 1
                ).first,
                let memoryId = memory.id
            {
                id = memoryId
            } else {
                throw MemoryMCPToolError.invalidArguments("Provide an existing `id` or `key`.")
            }

            try await repository.delete(id)
            return .success(
                toolName: call.name,
                payload: .object(["deleted": .bool(true), "id": .string(id)])
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: call.name, error)
        }
    }
}
