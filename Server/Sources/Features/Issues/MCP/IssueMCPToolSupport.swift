import Foundation

enum IssueMCPToolSupport {
    struct TimelineItemInput {
        let kind: String
        let description: String
    }

    static func optionalPriority(_ name: String, from call: MCPToolCall) -> IssuePriority? {
        guard let rawValue = MCPSupport.optionalInt(name, from: call) else {
            return nil
        }
        return IssuePriority(rawValue: rawValue)
    }

    static func finished(for status: IssueStatus) -> Bool {
        status == .resolved || status == .cancelled
    }

    static func issueObject(_ issue: Issue) -> MCPJSONValue {
        .object([
            "id": issue.id.map(MCPJSONValue.string) ?? .null,
            "title": .string(issue.title),
            "description": .string(issue.description),
            "initialRequest": .string(issue.initialRequest),
            "resolutionCondition": .string(issue.resolutionCondition),
            "priority": .integer(issue.priority.rawValue),
            "status": .string(issue.status.rawValue),
            "finished": .bool(issue.finished),
            "suspendUntil": issue.suspendUntil.map { .string(ISO8601DateFormatter().string(from: $0)) } ?? .null
        ])
    }

    static func issueList(_ issues: [Issue]) -> MCPJSONValue {
        .object([
            "count": .integer(issues.count),
            "issues": .array(issues.map(issueObject))
        ])
    }

    static func timelineItemObject(_ item: IssueTimelineItem) -> MCPJSONValue {
        .object([
            "id": item.id.map(MCPJSONValue.string) ?? .null,
            "issueId": .string(item.issueId),
            "kind": .string(item.kind),
            "description": .string(item.description)
        ])
    }

    static func timelineItemsObject(_ items: [IssueTimelineItem]) -> MCPJSONValue {
        .object([
            "count": .integer(items.count),
            "timelineItems": .array(items.map(timelineItemObject))
        ])
    }

    static func timelineItemInputs(from call: MCPToolCall) throws -> [TimelineItemInput] {
        guard let items = call.arguments["timelineItems"] else {
            return []
        }

        guard case .array(let values) = items else {
            throw MCPToolExtractionError.missingOrInvalid("timelineItems")
        }

        return try values.map { value in
            guard case .object(let object) = value else {
                throw MCPToolExtractionError.missingOrInvalid("timelineItems")
            }

            guard
                let kind = object["kind"]?.stringValue?.trimmedNonEmpty,
                let description = object["description"]?.stringValue?.trimmedNonEmpty
            else {
                throw MCPToolExtractionError.missingOrInvalid("timelineItems")
            }

            return TimelineItemInput(kind: kind, description: description)
        }
    }
}

enum IssueMCPToolError: Error, MCPServerErrorProviding {
    case issueNotFound(String)
    case issueFinished(String)

    var serverError: MCPServerError {
        switch self {
        case .issueNotFound(let id):
            return .executionFailed("Issue not found: \(id)")
        case .issueFinished(let id):
            return .executionFailed("Issue is already finished: \(id)")
        }
    }
}

extension IssueMCPToolError {
    init(repositoryError: IssueRepositoryError) {
        switch repositoryError {
        case .issueNotFound(let id):
            self = .issueNotFound(id)
        case .issueFinished(let id):
            self = .issueFinished(id)
        }
    }
}
