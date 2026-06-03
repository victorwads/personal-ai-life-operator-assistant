import Foundation

struct NativeSendMessageInteractor: SendMessageInteractor {
    typealias Input = SendMessageInput
    typealias Output = Void

    let runtime: AccessibilityRuntime

    func execute(_ input: SendMessageInput) async -> CrawlingResult<Void> {
        .failure(.notImplemented("Native message sending is not wired yet."))
    }
}
