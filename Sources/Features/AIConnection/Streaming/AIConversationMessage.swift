import Foundation

struct AIConversationMessage: Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    let role: Role
    let content: String?
    let name: String?
    let toolCallID: String?
    let toolCalls: [AIRequestedToolCall]

    init(
        role: Role,
        content: String? = nil,
        name: String? = nil,
        toolCallID: String? = nil,
        toolCalls: [AIRequestedToolCall] = []
    ) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallID = toolCallID
        self.toolCalls = toolCalls
    }
}
