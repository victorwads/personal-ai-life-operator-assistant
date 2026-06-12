import Foundation

struct WaitForEventTool: MCPToolDefinition {
    private let sharedLocks: SharedLockRegistry
    private let snapshotLoader: PendingWorkSnapshotLoader

    init(
        sharedLocks: SharedLockRegistry,
        pendingWorkProviders: [any PendingWorkProvider] = []
    ) {
        self.sharedLocks = sharedLocks
        self.snapshotLoader = PendingWorkSnapshotLoader(providers: pendingWorkProviders)
    }

    let name = "wait_for_event"
    let icon = "bell"
    let description = """
    The assistant calls this only when it has finished all immediately actionable work.

    It waits globally for any future event and must not wait for only one specific chat. It can wake on events such as chat_messages, client_prompt, or system_event. When it returns a chat_messages event, the assistant should call whatsapp_list_chat_messages(chatId, limit) next to load the actual message content.
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
        let initialSnapshot = try await snapshotLoader.load()
        if !initialSnapshot.isEmpty {
            return .string("Restart Session")
// TODO: stop losing user prompts
//            return .string(
//                PendingWorkTextRenderer.waitForEventMessage(
//                    for: initialSnapshot,
//                    trigger: .pendingAlreadyExists
//                )
//            )
        }

        try await sharedLocks.lockAndWait(id: SharedLockIDs.globalEvent)
        return .string("Restart Session")
// TODO: stop losing user prompts
//        return .string(
//            PendingWorkTextRenderer.waitForEventMessage(
//                for: try await snapshotLoader.load(),
//                trigger: .globalEventUnlocked
//            )
//        )
    }
}
