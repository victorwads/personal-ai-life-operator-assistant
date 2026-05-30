import Foundation

struct ListMemoriesTool: MCPToolHandler {
    private let repository: FirestoreMemoryRepository?

    static let definition = MCPToolDefinition(
        name: "list_memories",
        icon: "list.bullet.rectangle",
        description: "Lists all saved memory entries, including durable facts, recurring preferences, and standing instructions. Review this at startup and occasionally during long-running work so persistent context stays available.",
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:])
        ]),
        exampleParameters: [],
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

            let memories = try await repository.getAll()
            return .success(
                toolName: Self.definition.name,
                payload: MemoryMCPToolSupport.memoryList(memories)
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: Self.definition.name, error)
        }
    }
}
