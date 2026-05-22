import Foundation

struct ListMemoriesTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "list_memories",
        icon: "list.bullet.rectangle",
        description: "Lists all saved memory entries, including durable facts, recurring preferences, and standing instructions. Review this at startup and occasionally during long-running work so persistent context stays available.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([:])
        ],
        exampleParameters: [],
        traits: [.readOnly]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let entries = await context.memoriesRepository.list()
        return .success(.object([
            "entries": .array(entries.map(context.memoryEntryJSONValue))
        ]))
    }
}
