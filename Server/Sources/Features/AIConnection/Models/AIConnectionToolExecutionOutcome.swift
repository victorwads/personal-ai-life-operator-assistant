import Foundation

struct AIConnectionToolExecutionOutcome {
    let conversationMessages: [AIConversationMessage]
    let endsCycleAtIdleBoundary: Bool
}
