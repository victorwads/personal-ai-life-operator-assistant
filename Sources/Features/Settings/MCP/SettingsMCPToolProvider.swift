import Foundation

struct SettingsMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .utilities

    var tools: [any MCPToolHandler.Type] {
        [
            GetAssistantNameTool.self,
        ]
    }
}
