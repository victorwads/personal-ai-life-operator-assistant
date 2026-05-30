import Foundation

struct ListActiveIssuesTool: MCPToolDefinition {
    private let repository: FirestoreIssueRepository

    init(repository: FirestoreIssueRepository) {
        self.repository = repository
    }

    let name = "list_active_issues"
    let icon = "folder"
    let description = "Checks the currently active issues that still need follow-up."
    let group = "issues"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async -> MCPToolExecutionResult {
        do {
            let issues = try await repository.getActiveIssues()
            return .success(toolName: call.name, payload: IssueMCPToolSupport.issueList(issues))
        } catch {
            return IssueMCPToolSupport.failure(toolName: call.name, error)
        }
    }
}
