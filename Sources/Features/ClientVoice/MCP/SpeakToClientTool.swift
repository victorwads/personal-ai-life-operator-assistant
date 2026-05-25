import Foundation

struct SpeakToClientTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "speak_to_client",
        summary: "Speak or summarize something to the client.",
        group: .clientVoice,
        traits: [.sideEffect]
    )

    init() {}
}
