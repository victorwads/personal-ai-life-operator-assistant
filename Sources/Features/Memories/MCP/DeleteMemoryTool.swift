import Foundation

struct DeleteMemoryTool: MCPToolHandler {
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

    init() {}
}
