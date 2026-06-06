import Foundation

struct AIConnectionRequestLogContext {
    let cycleNumber: Int
    let requestIndex: Int
    let startedAt: Date
    let requestMessages: [AIConversationMessage]
    var provider: AIConnectionProviderKind?
    var model: String?
    var responseId: String?
    var didPersistPromptProcessing = false
}
