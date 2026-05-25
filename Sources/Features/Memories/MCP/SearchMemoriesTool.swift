import Foundation

struct SearchMemoriesTool: MCPToolHandler {
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

    init() {}
}
