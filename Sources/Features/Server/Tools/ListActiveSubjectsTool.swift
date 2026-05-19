import Foundation

struct ListActiveSubjectsTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "check_active_subjects",
        icon: "folder",
        description: "Checks the currently active subjects that still need follow-up.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([:])
        ],
        exampleParameters: [],
        traits: [.readOnly]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let entries = await context.subjectsRepository.listActive()
        return .success(.object([
            "entries": .array(entries.map(context.subjectEntryJSONValue))
        ]))
    }
}
