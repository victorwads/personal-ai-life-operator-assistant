import Foundation

struct GetMemoryTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_memory",
        icon: "brain",
        description: "Fetches one saved memory by its exact `key`. Use this only when you already know the key you want.",
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "key": .object(["type": .string("string")])
            ]),
            "required": .array([.string("key")])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("client_identity"))
        ],
        traits: [.readOnly]
    )

    init() {}
}
