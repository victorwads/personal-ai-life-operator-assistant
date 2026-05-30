import Foundation

struct CreateMemoryTool: MCPToolHandler {
    private let repository: FirestoreMemoryRepository?

    static let definition = MCPToolDefinition(
        name: "create_memory",
        icon: "brain",
        description: """
        Creates or updates a long-term memory entry keyed by `key`.

        Use this for durable facts and standing instructions that should keep influencing future interactions. If the key already exists, it updates the existing memory instead of creating a duplicate.

        Do not tell the user you will remember something unless you save the memory first.
        """,
        group: .memories,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "issueId": .object(["type": .string("string")]),
                "key": .object(["type": .string("string")]),
                "value": .object(["type": .string("string")])
            ]),
            "required": .array([.string("key"), .string("value")])
        ]),
        exampleParameters: [
            .init(name: "key", value: .string("victor_assertive_feedback_rule")),
            .init(name: "value", value: .string("Whenever Victor becomes rude or unnecessarily aggressive, explain calmly how he could have said it in a more assertive and non-violent way."))
        ],
        traits: [.writesState]
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

            let key = try MemoryMCPToolSupport.requiredString("key", from: call)
            let value = try MemoryMCPToolSupport.requiredString("value", from: call)
            let memory = try await repository.save(Memory(id: nil, key: key, value: value))

            return .success(
                toolName: Self.definition.name,
                payload: .object(["memory": MemoryMCPToolSupport.memoryObject(memory)])
            )
        } catch {
            return MemoryMCPToolSupport.failure(toolName: Self.definition.name, error)
        }
    }
}
