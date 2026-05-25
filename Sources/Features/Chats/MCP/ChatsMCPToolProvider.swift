import Foundation

struct ChatsMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .chats

    var tools: [any MCPToolHandler.Type] {
        [
            ListChatsTool.self,
            ListChatsBySearchTool.self,
            ListUnreadChatsTool.self,
            ListRecentMessagesTool.self,
            SendMessageTool.self,
            WaitForChatMessageTool.self,
            WaitForEventTool.self,
            WaitNextEventTool.self,
        ]
    }
}
