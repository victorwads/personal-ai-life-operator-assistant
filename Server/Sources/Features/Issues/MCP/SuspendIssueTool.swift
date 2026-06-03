import Foundation

struct SuspendIssueTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository
    private let timelineRepository: FirestoreIssueTimelineRepository

    init(repository: FirestoreIssueRepository, timelineRepository: FirestoreIssueTimelineRepository) {
        self.repository = repository
        self.timelineRepository = timelineRepository
    }

    let name = "suspend_issue"
    let icon = "pause.circle"
    let description = "Suspends an issue until a later date."
    let group = "issues"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object(["type": .string("string")]),
            "suspendUntil": .object(["type": .string("string")]),
            "reason": .object(["type": .string("string")])
        ]),
        "required": .array([.string("id"), .string("suspendUntil"), .string("reason")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "id", value: .string("issue-1")),
        .init(name: "suspendUntil", value: .string("2026-01-01T10:00:00Z")),
        .init(name: "reason", value: .string("Waiting for the client to respond."))
    ]
    let traits: [MCPToolTrait] = [.writesState]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let id = try MCPSupport.string("id", from: call)
        guard var issue = try await repository.getById(id) else {
            throw IssueMCPToolError.issueNotFound(id)
        }

        issue.status = .suspended
        issue.finished = false
        issue.suspendUntil = try MCPSupport.date("suspendUntil", from: call)

        let saved = try await repository.save(issue)
        let reason = try MCPSupport.string("reason", from: call)
        let timelineItem = try await timelineRepository.save(
            IssueTimelineItem(
                id: nil,
                issueId: saved.id ?? id,
                kind: "suspended",
                description: reason
            )
        )

        return .object([
            "issue": IssueMCPToolSupport.issueObject(saved),
            "timelineItem": IssueMCPToolSupport.timelineItemObject(timelineItem)
        ])
    }
}
