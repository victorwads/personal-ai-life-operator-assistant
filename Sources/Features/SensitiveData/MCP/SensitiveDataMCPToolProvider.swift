import Foundation

struct SensitiveDataMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .sensitiveData

    var tools: [MCPToolHandler.Type] {
        [
            SaveSensitiveDataTool.self,
            GetSensitiveDataTool.self,
            ListSensitiveDataTool.self,
            SearchSensitiveDataTool.self,
            UpdateSensitiveDataTool.self,
            DeleteSensitiveDataTool.self,
        ]
    }
}
