import Foundation

struct MemoriesMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .memories

    var tools: [any MCPToolHandler.Type] {
        [
            CreateMemoryTool.self,
            GetMemoryTool.self,
            ListMemoriesTool.self,
            SearchMemoriesTool.self,
            DeleteMemoryTool.self,
        ]
    }
}
