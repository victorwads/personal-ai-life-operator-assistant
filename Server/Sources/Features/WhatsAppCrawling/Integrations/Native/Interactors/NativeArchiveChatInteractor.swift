import Foundation

struct NativeArchiveChatInteractor: ArchiveChatInteractor {
    typealias Input = CrawledChat
    typealias Output = Void

    let runtime: AccessibilityRuntime

    func execute(_ input: CrawledChat) async -> CrawlingResult<Void> {
        .failure(.notImplemented("Native chat archiving is not wired yet."))
    }
}
