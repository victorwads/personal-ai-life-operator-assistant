import Foundation

struct DeleteMemoryTool: MCPToolHandler {
    private let repository: FirestoreMemoryRepository?

    static let definition = MCPToolDefinition(
        name: "delete_memory",
        icon: "trash",
        description: "Deletes a saved memory by `key` or `id`. Use this only when a memory is wrong, obsolete, duplicated, or should no longer guide future behavior.",
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "issueId": .object(["type": .string("string")]),
                "id": .object(["type": .string("string")]),
                "key": .object(["type": .string("string")])
            ])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("client_identity"))
        ],
        traits: [.writesState]
    )

    init() {
        self.repository = nil
    }

    init(repository: FirestoreMemoryRepository?) {
        self.repository = repository
    }

    func handle(_ call: MCPToolCall, context: MCPServerContext) async -> MCPToolExecutionResult {
        do {
            guard let repository = MemoryMCPToolSupport.repository(explicit: repository, context: context) else {
                throw MemoryMCPToolError.repositoryUnavailable
            }

            let id: String
            if let providedId = MemoryMCPToolSupport.optionalString("id", from: call) {
                id = providedId
            } else if
                let key = MemoryMCPToolSupport.optionalString("key", from: call),
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
                toolName: Self.definition.name,
                payload: .object(["deleted": .bool(true), "id": .string(id)])
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: Self.definition.name, error)
        }
    }
}
