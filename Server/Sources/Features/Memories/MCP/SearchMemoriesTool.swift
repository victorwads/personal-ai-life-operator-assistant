import Foundation

struct SearchMemoriesTool: MCPToolDefinition {
    private let repository: FirestoreMemoryRepository

    init(repository: FirestoreMemoryRepository) {
        self.repository = repository
    }

    let name = "search_memories"
    let icon = "magnifyingglass"
    let description = "Searches memories by textual similarity and returns the best matches. Use this when you know a word, phrase, or rough description but not the exact memory key."
    let group = "memories"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object(["type": .string("string")]),
            "limit": .object(["type": .string("number")])
        ]),
        "required": .array([.string("query")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "query", value: .string("plano de saúde"))
    ]
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let query = try MCPSupport.string("query", from: call)
        let limit = MCPSupport.optionalLimit(from: call, default: 10)
        let normalizedQuery = query.localizedLowercase
        let memories = try await repository.getAll()
            .filter { memory in
                memory.key.localizedLowercase.contains(normalizedQuery)
                    || memory.value.localizedLowercase.contains(normalizedQuery)
            }
            .prefix(limit)

        return MemoryMCPToolSupport.memoryList(Array(memories))
    }
}
