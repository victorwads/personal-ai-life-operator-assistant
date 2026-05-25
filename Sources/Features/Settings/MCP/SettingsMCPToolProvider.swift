import Foundation

struct SettingsMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .utilities

    var tools: [MCPToolHandler.Type] {
        [
            GetAssistantNameTool.self,
        ]
    }
}
