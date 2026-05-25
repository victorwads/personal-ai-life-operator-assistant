import Foundation

struct ChatsMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .chats

    var tools: [MCPToolHandler.Type] {
        [
            ListChatsBySearchTool.self,
            ListUnhandledChatsTool.self,
            ListChatMessagesTool.self,
            SendMessageTool.self,
            WaitForEventTool.self,
        ]
    }
}
