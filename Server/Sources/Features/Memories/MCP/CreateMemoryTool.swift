import Foundation

struct CreateMemoryTool: MCPToolDefinition {
    private let repository: FirestoreMemoryRepository

    init(repository: FirestoreMemoryRepository) {
        self.repository = repository
    }

    let name = "create_memory"
    let icon = "brain"
    let description = """
    Creates or updates a long-term memory entry keyed by `key`.

    Use this for durable facts and standing instructions that should keep influencing future interactions. If the key already exists, it updates the existing memory instead of creating a duplicate.

    Do not tell the user you will remember something unless you save the memory first.
    """
    let group = "memories"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "key": .object(["type": .string("string")]),
            "value": .object(["type": .string("string")])
        ]),
        "required": .array([.string("key"), .string("value")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "key", value: .string("victor_assertive_feedback_rule")),
        .init(name: "value", value: .string("Whenever Victor becomes rude or unnecessarily aggressive, explain calmly how he could have said it in a more assertive and non-violent way."))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let key = try MCPSupport.string("key", from: call)
        let value = try MCPSupport.string("value", from: call)
        let memory = try await repository.saveByKey(key: key, value: value)

        return .object(["memory": MemoryMCPToolSupport.memoryObject(memory)])
    }
}
