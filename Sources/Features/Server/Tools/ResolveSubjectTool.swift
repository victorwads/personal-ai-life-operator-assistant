import Foundation

struct ResolveSubjectTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "resolve_subject",
        description: "Marks a subject as resolved by id and reason.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([
                "id": .object(["type": .string("string")]),
                "reason": .object(["type": .string("string")])
            ]),
            "required": .array([.string("id"), .string("reason")])
        ],
        exampleParameters: [
            .init(name: "id", value: .string("22222222-2222-2222-2222-222222222222")),
            .init(name: "reason", value: .string("Task completed and confirmed with the client."))
        ],
        traits: [.writesState]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let arguments = MCPToolArguments(values: call.arguments)
        guard let id = arguments.uuid(for: "id") else {
            return .failure(SubjectsRepositoryError.invalidParameter("Invalid id"))
        }
        guard let reason = arguments.string(for: "reason"), !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(SubjectsRepositoryError.missingParameter("reason"))
        }

        do {
            let entry = try await context.subjectsRepository.resolve(id: id, reason: reason)
            return .success(.object([
                "ok": .bool(true),
                "entry": context.subjectEntryJSONValue(entry)
            ]))
        } catch {
            return .failure(error)
        }
    }
}
