import Foundation

struct CreateIssueTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository

    init(repository: FirestoreIssueRepository) {
        self.repository = repository
    }

    let name = "create_issue"
    let icon = "folder.badge.plus"
    let description = "Creates a new operational issue."
    let group = "issues"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "title": .object(["type": .string("string")]),
            "description": .object(["type": .string("string")]),
            "initialRequest": .object(["type": .string("string")]),
            "resolutionCondition": .object(["type": .string("string")]),
            "priority": .object(["type": .string("number")])
        ]),
        "required": .array([
            .string("title"),
            .string("description"),
            .string("initialRequest"),
            .string("resolutionCondition")
        ])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "title", value: .string("Preview issue")),
        .init(name: "description", value: .string("Issue created from the tools browser preview.")),
        .init(name: "initialRequest", value: .string("Build the new server tools browser.")),
        .init(name: "resolutionCondition", value: .string("The browser shows the issue with all core fields and the create/update flow works end to end.")),
        .init(name: "priority", value: .integer(3))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let saved = try await repository.save(
            Issue(
                id: nil,
                title: try MCPSupport.string("title", from: call),
                description: try MCPSupport.string("description", from: call),
                initialRequest: try MCPSupport.string("initialRequest", from: call),
                resolutionCondition: try MCPSupport.string("resolutionCondition", from: call),
                priority: IssueMCPToolSupport.optionalPriority("priority", from: call) ?? .medium,
                status: .pending,
                finished: false,
                suspendUntil: nil
            )
        )

        return .object(["issue": IssueMCPToolSupport.issueObject(saved)])
    }
}
