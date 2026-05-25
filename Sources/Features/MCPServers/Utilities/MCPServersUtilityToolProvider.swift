import Foundation

struct MCPServersUtilityToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .utilities

    var tools: [any MCPToolHandler.Type] {
        [
            GetCurrentDateTool.self,
        ]
    }
}
