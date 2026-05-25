import Foundation

struct IssuesMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .issues

    var tools: [any MCPToolHandler.Type] {
        [
            CreateIssueTool.self,
            UpdateIssueTool.self,
            GetIssueTool.self,
            ListActiveIssuesTool.self,
            ResolveIssueTool.self,
            CancelIssueTool.self,
        ]
    }
}
