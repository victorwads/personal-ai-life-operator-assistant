import Foundation

struct NativeSearchChatInteractor: SearchChatInteractor {
    typealias Input = String
    typealias Output = Void

    let runtime: AccessibilityRuntime

    func execute(_ input: String) async -> CrawlingResult<Void> {
        .failure(.notImplemented("Native chat search is not wired yet."))
    }
}
