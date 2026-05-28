import Foundation

struct MCPServersUtilityToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .utilities

    var tools: [MCPToolHandler.Type] {
        [
            GetCurrentDateTool.self,
            GetAssistantNameTool.self,
        ]
    }
}
