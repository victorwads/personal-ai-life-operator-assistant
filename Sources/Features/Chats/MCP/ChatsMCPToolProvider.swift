import Foundation

struct ChatsMCPToolProvider: MCPToolProvider {
    let group: MCPToolGroup = .chats

    var tools: [any MCPToolHandler.Type] {
        [
            ListChatsBySearchTool.self,
            ListUnhandledChatsTool.self,
            ListChatMessagesTool.self,
            SendMessageTool.self,
            WaitForEventTool.self,
        ]
    }
}
