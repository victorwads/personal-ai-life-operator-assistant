import Foundation

struct AIConnectionRequestLogContext {
    let cycleNumber: Int
    let requestIndex: Int
    let startedAt: Date
    var provider: AIConnectionProviderKind?
    var model: String?
    var responseId: String?
    var didPersistPromptProcessing = false
}
