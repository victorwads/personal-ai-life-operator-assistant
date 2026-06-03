import Foundation

struct WaitForEventTool: MCPToolDefinition {
    private let sharedLocks: SharedLockRegistry

    init(sharedLocks: SharedLockRegistry) {
        self.sharedLocks = sharedLocks
    }

    let name = "wait_for_event"
    let icon = "bell"
    let description = """
    The assistant calls this only when it has finished all immediately actionable work.

    It waits globally for any future event and must not wait for only one specific chat. It can wake on events such as chat_messages, client_prompt, or system_event. When it returns a chat_messages event, the assistant should call list_chat_messages(chatId, limit) next to load the actual message content.
    """
    let group = "chats"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.blocking]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        _ = call
        try await sharedLocks.lockAndWait(id: SharedLockIDs.globalEvent)
        return .string("event: something changed. Re-check active chats, issues, and pending client interactions.")
    }
}
