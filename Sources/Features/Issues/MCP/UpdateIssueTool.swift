import Foundation

struct UpdateIssueTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository
    private let timelineRepository: FirestoreIssueTimelineRepository

    init(repository: FirestoreIssueRepository, timelineRepository: FirestoreIssueTimelineRepository) {
        self.repository = repository
        self.timelineRepository = timelineRepository
    }

    let name = "update_issue"
    let icon = "pencil"
    let description = "Updates an existing operational issue by id."
    let group = "issues"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object(["type": .string("string")]),
            "description": .object(["type": .string("string")]),
            "resolutionCondition": .object(["type": .string("string")]),
            "priority": .object(["type": .string("number")]),
            "timelineItems": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "kind": .object(["type": .string("string")]),
                        "description": .object(["type": .string("string")])
                    ]),
                    "required": .array([.string("kind"), .string("description")])
                ])
            ])
        ]),
        "required": .array([.string("id")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "id", value: .string("issue-1")),
        .init(name: "description", value: .string("Updated from the preview browser.")),
        .init(name: "priority", value: .integer(4)),
        .init(name: "timelineItems", value: .array([
            .object([
                "kind": .string("client_message_sent"),
                "description": .string("Sent a follow-up message to the client.")
            ])
        ]))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async -> MCPToolExecutionResult {
        do {
            let id = try MCPToolArguments.requiredString("id", from: call)
            guard var issue = try await repository.getById(id) else {
                throw IssueMCPToolError.issueNotFound(id)
            }

            if let description = MCPToolArguments.optionalString("description", from: call) {
                issue.description = description
            }
            if let resolutionCondition = MCPToolArguments.optionalString("resolutionCondition", from: call) {
                issue.resolutionCondition = resolutionCondition
            }
            if let priority = IssueMCPToolSupport.optionalPriority("priority", from: call) {
                issue.priority = priority
            }

            let saved = try await repository.save(issue)
            let timelineInputs = try IssueMCPToolSupport.timelineItemInputs(from: call)
            var timelineItems: [IssueTimelineItem] = []
            for input in timelineInputs {
                timelineItems.append(
                    try await timelineRepository.save(
                        IssueTimelineItem(
                            id: nil,
                            issueId: saved.id ?? id,
                            kind: input.kind,
                            description: input.description
                        )
                    )
                )
            }
            return .success(
                toolName: call.name,
                payload: .object([
                    "issue": IssueMCPToolSupport.issueObject(saved),
                    "timelineItems": IssueMCPToolSupport.timelineItemsObject(timelineItems)
                ])
            )
        } catch {
            return IssueMCPToolSupport.failure(toolName: call.name, error)
        }
    }
}
