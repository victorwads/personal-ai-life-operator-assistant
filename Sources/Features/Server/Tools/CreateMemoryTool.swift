import Foundation

struct CreateMemoryTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "create_memory",
        description: "Creates or updates a long-term memory entry keyed by `key`.\n\nUse this for durable facts and persistent instructions the assistant must keep applying in future interactions. This includes standing instructions, recurring corrections, behavioral preferences, durable constraints, and anything the user expects you to remember across future conversations.\n\nAlways save a memory before replying if the user communicates any of these patterns:\n- remember this\n- do not forget\n- always / every time / from now on\n- preferred behavior, correction style, or standing instruction\n- recurring preference or durable constraint\n- anything the assistant promises to keep doing in the future\n\nDo not tell the user you will remember something unless you save the memory first. If the key already exists, this tool updates the existing memory instead of creating a duplicate.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "key": .object(["type": .string("string")]),
                "content": .object(["type": .string("string")]),
                "tags": .object(["type": .string("array"), "items": .object(["type": .string("string")])])
            ]),
            "required": .array([.string("key"), .string("content")])
        ],
        exampleParameters: [
            .init(name: "key", value: .string("victor_assertive_feedback_rule")),
            .init(name: "content", value: .string("Whenever Victor becomes rude or unnecessarily aggressive, explain calmly how he could have said it in a more assertive and non-violent way.")),
            .init(name: "tags", value: .array([.string("behavior"), .string("standing_instruction"), .string("victor")]))
        ],
        traits: [.writesState]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let arguments = MCPToolArguments(values: call.arguments)
        do {
            let result = try await context.memoriesRepository.save(
                key: arguments.string(for: "key"),
                content: arguments.string(for: "content"),
                tags: arguments.stringArray(for: "tags")
            )
            return .success(.object([
                "ok": .bool(true),
                "created": .bool(result.created),
                "updated": .bool(result.updated),
                "entry": context.memoryEntryJSONValue(result.entry)
            ]))
        } catch {
            return .failure(error)
        }
    }
}
