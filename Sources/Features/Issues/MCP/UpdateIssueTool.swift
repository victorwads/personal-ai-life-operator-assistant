import Foundation

struct UpdateIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "update_issue",
        icon: "pencil",
        description: """
        Updates an existing operational issue by id.

        Use this tool to change fields and record progress while the issue is still open.

        Rules:
        - `nextSteps` replaces the current array
        - `appendUpdatesLog` appends new updates and ignores exact duplicates
        - `resolutionCondition` can be refined as the understanding of completion changes
        """,
        group: .issues,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "issueId": .object(["type": .string("string")]),
                "title": .object(["type": .string("string")]),
                "summary": .object(["type": .string("string")]),
                "resolutionCondition": .object(["type": .string("string")]),
                "details": .object(["type": .string("string")]),
                "priority": .object(["type": .string("number")]),
                "participants": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")])
                ]),
                "nextSteps": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")])
                ]),
                "appendUpdatesLog": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")])
                ]),
                "whatsappChatId": .object(["type": .string("string")]),
                "whatsappAfterMessageId": .object(["type": .string("string")]),
                "gmailThreadId": .object(["type": .string("string")]),
                "calendarEventId": .object(["type": .string("string")])
            ]),
            "required": .array([.string("issueId")])
        ]),
        exampleParameters: [
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "title", value: .string("Preview issue updated")),
            .init(name: "summary", value: .string("Updated from the preview browser.")),
            .init(name: "resolutionCondition", value: .string("The issue shows the revised end condition and the work can be closed when it is met.")),
            .init(name: "details", value: .string("Expanded with more context.")),
            .init(name: "priority", value: .integer(2)),
            .init(name: "participants", value: .array([.string("Codex"), .string("Client")])),
            .init(name: "nextSteps", value: .array([.string("Review")])),
            .init(name: "appendUpdatesLog", value: .array([.string("Confirmed the next follow-up action with the client.")])),
            .init(name: "whatsappChatId", value: .string("chat-1")),
            .init(name: "whatsappAfterMessageId", value: .string("m2"))
        ],
        traits: [.writesState]
    )

    init() {}
}
