import Foundation

struct ClientVoiceMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .clientVoice

    var tools: [MCPToolHandler.Type] {
        [
            SpeakToClientTool.self,
            AskToClientTool.self,
        ]
    }
}
