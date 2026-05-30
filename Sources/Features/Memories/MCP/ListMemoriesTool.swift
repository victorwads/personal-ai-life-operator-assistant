import Foundation

struct ListMemoriesTool: MCPToolDefinition {
    private let repository: FirestoreMemoryRepository

    init(repository: FirestoreMemoryRepository) {
        self.repository = repository
    }

    let name = "list_memories"
    let icon = "list.bullet.rectangle"
    let description = "Lists all saved memory entries, including durable facts, recurring preferences, and standing instructions. Review this at startup and occasionally during long-running work so persistent context stays available."
    let group = "memories"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async -> MCPToolExecutionResult {
        do {
            let memories = try await repository.getAll()
            return .success(
                toolName: call.name,
                payload: MemoryMCPToolSupport.memoryList(memories)
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: call.name, error)
        }
    }
}
