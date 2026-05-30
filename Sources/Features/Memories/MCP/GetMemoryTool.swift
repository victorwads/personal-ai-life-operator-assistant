import Foundation

struct GetMemoryTool: MCPToolHandler {
    private let repository: FirestoreMemoryRepository?

    static let definition = MCPToolDefinition(
        name: "get_memory",
        icon: "brain",
        description: "Fetches one saved memory by its exact `key`. Use this only when you already know the key you want.",
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object(["type": .string("string")]),
                "key": .object(["type": .string("string")])
            ])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("client_identity"))
        ],
        traits: [.readOnly]
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

            let memory: Memory?
            if let id = MemoryMCPToolSupport.optionalString("id", from: call) {
                memory = try await repository.getById(id)
            } else if let key = MemoryMCPToolSupport.optionalString("key", from: call) {
                memory = try await repository.query(
                    matching: ["key": key],
                    limit: 1
                ).first
            } else {
                throw MemoryMCPToolError.invalidArguments("Provide either `id` or `key`.")
            }

            return .success(
                toolName: Self.definition.name,
                payload: .object([
                    "memory": memory.map(MemoryMCPToolSupport.memoryObject) ?? .null
                ])
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: Self.definition.name, error)
        }
    }
}
