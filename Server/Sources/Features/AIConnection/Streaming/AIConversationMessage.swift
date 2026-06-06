import Foundation

enum AIConversationContent: Equatable, Sendable {
    case text(String)
    case parts([AIConversationContentPart])
}

enum AIConversationContentPart: Equatable, Sendable {
    case text(String)
    case imageURL(String)
}

struct AIConversationMessage: Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    let role: Role
    let contentValue: AIConversationContent?
    let name: String?
    let toolCallID: String?
    let toolCalls: [AIRequestedToolCall]

    var content: String? {
        switch contentValue {
        case let .text(content):
            return content
        case .parts, nil:
            return nil
        }
    }

    var contentParts: [AIConversationContentPart]? {
        guard case let .parts(parts) = contentValue else { return nil }
        return parts
    }

    init(
        role: Role,
        content: String? = nil,
        name: String? = nil,
        toolCallID: String? = nil,
        toolCalls: [AIRequestedToolCall] = []
    ) {
        self.role = role
        self.contentValue = content.map { .text($0) }
        self.name = name
        self.toolCallID = toolCallID
        self.toolCalls = toolCalls
    }

    init(
        role: Role,
        contentParts: [AIConversationContentPart],
        name: String? = nil,
        toolCallID: String? = nil,
        toolCalls: [AIRequestedToolCall] = []
    ) {
        self.role = role
        self.contentValue = contentParts.isEmpty ? nil : .parts(contentParts)
        self.name = name
        self.toolCallID = toolCallID
        self.toolCalls = toolCalls
    }
}
