import Foundation

struct ChatState: Codable, Equatable {
    let chat: ConversationSummary
    let messages: [Message]
    let composeFocused: Bool
    let canSendText: Bool
}

extension ChatState {
    func replacing(
        chat: ConversationSummary? = nil,
        messages: [Message]? = nil,
        composeFocused: Bool? = nil,
        canSendText: Bool? = nil
    ) -> ChatState {
        ChatState(
            chat: chat ?? self.chat,
            messages: messages ?? self.messages,
            composeFocused: composeFocused ?? self.composeFocused,
            canSendText: canSendText ?? self.canSendText
        )
    }
}
