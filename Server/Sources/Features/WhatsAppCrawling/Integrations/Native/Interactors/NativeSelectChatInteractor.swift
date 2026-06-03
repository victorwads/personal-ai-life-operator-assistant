import Foundation

struct NativeSelectChatInteractor: SelectChatInteractor {
    typealias Input = CrawledChat
    typealias Output = Void

    let runtime: AccessibilityRuntime

    func execute(_ input: CrawledChat) async -> CrawlingResult<Void> {
        .failure(.notImplemented("Native chat selection is not wired yet."))
    }
}
