import Foundation

struct CreateIssueTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "create_issue",
        icon: "folder.badge.plus",
        description: """
        Creates a new operational issue.

        Use this to start tracking work that needs follow-up, execution, or closure.

        `initialRequest` captures the trigger and is immutable after creation.
        `resolutionCondition` captures the observable condition that must be satisfied before the issue can be resolved.
        Use `update_issue(...)` to record progress over time and refine the resolution condition if needed.
        """,
        group: .issues,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object(["type": .string("string")]),
                "summary": .object(["type": .string("string")]),
                "initialRequest": .object(["type": .string("string")]),
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
                "whatsappChatId": .object(["type": .string("string")]),
                "gmailThreadId": .object(["type": .string("string")]),
                "calendarEventId": .object(["type": .string("string")])
            ]),
            "required": .array([
                .string("title"),
                .string("summary"),
                .string("initialRequest"),
                .string("resolutionCondition"),
                .string("priority")
            ])
        ]),
        exampleParameters: [
            .init(name: "title", value: .string("Preview issue")),
            .init(name: "summary", value: .string("Issue created from the tools browser preview.")),
            .init(name: "initialRequest", value: .string("Build the new server tools browser.")),
            .init(name: "resolutionCondition", value: .string("The browser shows the issue with all core fields and the create/update flow works end to end.")),
            .init(name: "details", value: .string("Optional supporting details for the issue.")),
            .init(name: "priority", value: .integer(1)),
            .init(name: "participants", value: .array([.string("Codex")])),
            .init(name: "nextSteps", value: .array([.string("Validate the preview")])),
            .init(name: "whatsappChatId", value: .string("chat-1"))
        ],
        traits: [.writesState]
    )

    init() {}
}
