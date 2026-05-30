import Foundation

struct GetMemoryTool: MCPToolDefinition {
    private let repository: FirestoreMemoryRepository

    init(repository: FirestoreMemoryRepository) {
        self.repository = repository
    }

    let name = "get_memory"
    let icon = "brain"
    let description = "Fetches one saved memory by its exact `key`. Use this only when you already know the key you want."
    let group = "memories"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object(["type": .string("string")]),
            "key": .object(["type": .string("string")])
        ])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "key", value: .string("client_identity"))
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async -> MCPToolExecutionResult {
        do {
            let memory: Memory?
            if let id = MCPToolArguments.optionalString("id", from: call) {
                memory = try await repository.getById(id)
            } else if let key = MCPToolArguments.optionalString("key", from: call) {
                memory = try await repository.query(
                    matching: ["key": key],
                    limit: 1
                ).first
            } else {
                throw MemoryMCPToolError.invalidArguments("Provide either `id` or `key`.")
            }

            return .success(
                toolName: call.name,
                payload: .object([
                    "memory": memory.map(MemoryMCPToolSupport.memoryObject) ?? .null
                ])
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: call.name, error)
        }
    }
}
