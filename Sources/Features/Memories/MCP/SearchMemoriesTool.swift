import Foundation

struct SearchMemoriesTool: MCPToolHandler {
    private let repository: FirestoreMemoryRepository?

    static let definition = MCPToolDefinition(
        name: "search_memories",
        icon: "magnifyingglass",
        description: "Searches memories by textual similarity and returns the best matches. Use this when you know a word, phrase, or rough description but not the exact memory key.",
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object(["type": .string("string")]),
                "limit": .object(["type": .string("number")])
            ]),
            "required": .array([.string("query")])
        ]),
        exampleParameters: [
            .init(name: "query", value: .string("plano de saúde"))
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

            let query = try MemoryMCPToolSupport.requiredString("query", from: call)
            let limit = MemoryMCPToolSupport.optionalLimit(from: call, default: 10)
            let normalizedQuery = query.localizedLowercase
            let memories = try await repository.getAll()
                .filter { memory in
                    memory.key.localizedLowercase.contains(normalizedQuery)
                        || memory.value.localizedLowercase.contains(normalizedQuery)
                }
                .prefix(limit)

            return .success(
                toolName: Self.definition.name,
                payload: MemoryMCPToolSupport.memoryList(Array(memories))
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: Self.definition.name, error)
        }
    }
}
