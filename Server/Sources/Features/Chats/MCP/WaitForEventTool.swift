import Foundation

struct WaitForEventTool: MCPToolDefinition {
    private let sharedLocks: SharedLockRegistry
    private let pendingWorkProviders: [any PendingWorkProvider]

    init(
        sharedLocks: SharedLockRegistry,
        pendingWorkProviders: [any PendingWorkProvider] = []
    ) {
        self.sharedLocks = sharedLocks
        self.pendingWorkProviders = pendingWorkProviders
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
        for provider in pendingWorkProviders {
            if try await provider.hasPendingWork() {
                return .string(
                    "event: pending work already exists. Start a new cycle and inspect active chats, issues, and client interactions."
                )
            }
        }

        try await sharedLocks.lockAndWait(id: SharedLockIDs.globalEvent)
        return .string(
            "event: something changed. Start a new cycle and inspect active chats, issues, and client interactions."
        )
    }
}
