import Foundation

struct SpeakToClientTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "speak_to_client",
        icon: "speaker.wave.2",
        description: "Used when the assistant informs, summarizes progress, confirms completion, or closes a loop without requiring an answer from the client. Voice and language settings come from Settings, not from this MCP call.",
        group: .clientVoice,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "issueId": .object(["type": .string("string")]),
                "text": .object(["type": .string("string")])
            ]),
            "required": .array([.string("issueId"), .string("text")])
        ]),
        exampleParameters: [
            .init(name: "issueId", value: .string("issue-1")),
            .init(name: "text", value: .string("Testing speak_to_client from the tools browser."))
        ],
        traits: [.sideEffect]
    )

    init() {}
}
