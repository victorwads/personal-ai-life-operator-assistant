import Foundation

enum IssueMCPToolSupport {
    private static let activeIssueDescriptionLimit = 120

    struct TimelineItemInput {
        let kind: String
        let description: String
    }

    struct RelatedChatSummary {
        let id: String
        let title: String?
    }

    struct DetailedIssueData {
        let timelineItems: [IssueTimelineItem]
        let relatedChats: [RelatedChatSummary]
        let sentMessages: [SentMessage]
        let clientInteractionRequests: [ClientInteractionRequest]
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

    static func activeIssueListText(_ issues: [Issue]) -> MCPJSONValue {
        guard !issues.isEmpty else {
            return .string("No active issues found.")
        }

        let rendered = issues.map(renderActiveIssue)
        return .string(rendered.joined(separator: "\n\n"))
    }

    static func detailedIssueText(
        issue: Issue,
        relatedData: DetailedIssueData
    ) -> MCPJSONValue {
        .string(renderDetailedIssue(issue, relatedData: relatedData))
    }

    private static func renderActiveIssue(_ issue: Issue) -> String {
        let issueId = issue.id ?? "unknown"
        let description = truncated(issue.description, limit: activeIssueDescriptionLimit)

        return [
            "<issue id=\"\(issueId)\">",
            renderedElement("title", issue.title),
            renderedElement("description", description),
            "</issue>"
        ]
        .joined(separator: "\n")
    }

    private static func renderDetailedIssue(
        _ issue: Issue,
        relatedData: DetailedIssueData
    ) -> String {
        let issueId = issue.id ?? "unknown"
        var lines: [String] = [
            "<issue id=\"\(issueId)\">",
            renderedElement("title", issue.title),
            renderedElement("description", issue.description),
            renderedElement("initialRequest", issue.initialRequest),
            renderedElement("resolutionCondition", issue.resolutionCondition),
            "<priority number=\"\(issue.priority.rawValue)\">\(priorityLabel(for: issue.priority))</priority>",
            renderedElement("status", issue.status.rawValue)
        ]

        if let suspendUntil = issue.suspendUntil {
            lines.append(renderedElement("suspendUntil", ISO8601DateFormatter().string(from: suspendUntil)))
        }

        if !relatedData.timelineItems.isEmpty {
            lines.append(renderedTimeline(relatedData.timelineItems))
        }

        if !relatedData.relatedChats.isEmpty {
            lines.append(renderedRelatedChats(relatedData.relatedChats))
        }

        if !relatedData.sentMessages.isEmpty {
            lines.append(renderedSentMessages(relatedData.sentMessages))
        }

        if !relatedData.clientInteractionRequests.isEmpty {
            lines.append(renderedClientInteractionRequests(relatedData.clientInteractionRequests))
        }

        lines.append("</issue>")
        return lines.joined(separator: "\n")
    }

    private static func renderedTimeline(_ items: [IssueTimelineItem]) -> String {
        let body = items.map { renderedElement("item", $0.description) }.joined(separator: "\n")
        return wrappedBlock("timeline", body: body)
    }

    private static func renderedRelatedChats(_ chats: [RelatedChatSummary]) -> String {
        let body = chats.map { chat in
            var lines = ["<chat id=\"\(chat.id)\">"]
            if let title = chat.title, !title.isEmpty {
                lines.append(renderedElement("title", title))
            }
            lines.append("</chat>")
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n")

        return wrappedBlock("relatedChats", body: body)
    }

    private static func renderedSentMessages(_ sentMessages: [SentMessage]) -> String {
        let body = sentMessages.map { message in
            var attributes = [
                "chatId=\"\(message.chatId)\"",
                "status=\"\(message.status.rawValue)\""
            ]
            if let sentAt = message.sentAt {
                attributes.append("sentAt=\"\(ISO8601DateFormatter().string(from: sentAt))\"")
            }

            var lines = ["<sentMessage \(attributes.joined(separator: " "))>"]
            if let chatTitle = message.chatTitle, !chatTitle.isEmpty {
                lines.append(renderedElement("chatTitle", chatTitle))
            }
            for content in message.messages {
                lines.append(renderedElement("content", content))
            }
            if let errorMessage = message.errorMessage, !errorMessage.isEmpty {
                lines.append(renderedElement("errorMessage", errorMessage))
            }
            lines.append("</sentMessage>")
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n")

        return wrappedBlock("sentMessages", body: body)
    }

    private static func renderedClientInteractionRequests(_ requests: [ClientInteractionRequest]) -> String {
        let body = requests.map { request in
            var attributes = [
                "kind=\"\(request.kind.rawValue)\"",
                "status=\"\(request.status.rawValue)\""
            ]
            if let device = request.device?.rawValue, !device.isEmpty {
                attributes.append("device=\"\(device)\"")
            }

            var lines = ["<clientVoice \(attributes.joined(separator: " "))>"]
            lines.append(renderedElement("prompt", request.promptText))
            if let responseText = request.responseText, !responseText.isEmpty {
                lines.append(renderedElement("response", responseText))
            }
            lines.append("</clientVoice>")
            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n")

        return wrappedBlock("clientInteractions", body: body)
    }

    private static func wrappedBlock(_ name: String, body: String) -> String {
        [
            "<\(name)>",
            body,
            "</\(name)>"
        ]
        .joined(separator: "\n")
    }

    private static func renderedElement(_ name: String, _ value: String) -> String {
        "<\(name)>\(value)</\(name)>"
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        guard value.count > limit, limit > 3 else {
            return value
        }

        let endIndex = value.index(value.startIndex, offsetBy: limit - 3)
        return String(value[..<endIndex]) + "..."
    }

    private static func priorityLabel(for priority: IssuePriority) -> String {
        switch priority {
        case .urgent:
            return "altissima"
        case .high:
            return "alta"
        case .medium:
            return "media"
        case .low:
            return "baixa"
        case .veryLow:
            return "muito baixa"
        }
    }
}

enum IssueMCPToolError: Error, MCPServerErrorProviding {
    case issueNotFound(String)
    case issueFinished(String)
    case invalidReason(String)

    var serverError: MCPServerError {
        switch self {
        case .issueNotFound(let id):
            return .executionFailed("Issue not found: \(id)")
        case .issueFinished(let id):
            return .executionFailed("Issue is already finished: \(id)")
        case .invalidReason(let message):
            return .executionFailed(message)
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
        case .invalidReason(let message):
            self = .invalidReason(message)
        }
    }
}
