import Foundation

struct WaitForEventTool: MCPToolDefinition {
    // TODO: Decide how queued events are emitted. If multiple chats have pending messages, events may need to be returned one at a time. If multiple client prompts exist, they may need to be returned one at a time. The event queue behavior must be carefully designed.
    // TODO: If unresolved issues exist when the assistant calls wait_for_event, consider accepting a summary of unresolved issue IDs and why each one is blocked. This would make the assistant explicitly justify why it is going idle.
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
}
