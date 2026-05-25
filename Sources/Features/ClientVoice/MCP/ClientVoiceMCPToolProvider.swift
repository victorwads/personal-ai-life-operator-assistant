import Foundation

struct ClientVoiceMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .clientVoice

    var tools: [any MCPToolHandler.Type] {
        [
            SpeakToClientTool.self,
            AskToClientTool.self,
        ]
    }
}
