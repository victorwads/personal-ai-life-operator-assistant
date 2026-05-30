import Foundation

struct SpeakToClientTool: MCPToolDefinition {
    let name = "speak_to_client"
    let icon = "speaker.wave.2"
    let description = "Used when the assistant informs, summarizes progress, confirms completion, or closes a loop without requiring an answer from the client. Voice and language settings come from Settings, not from this MCP call."
    let group = "clientVoice"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "issueId": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")])
        ]),
        "required": .array([.string("issueId"), .string("text")])
    ])
    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "issueId", value: .string("issue-1")),
        .init(name: "text", value: .string("Testing speak_to_client from the tools browser."))
    ]
    let traits: [MCPToolTrait] = [.sideEffect]
}
