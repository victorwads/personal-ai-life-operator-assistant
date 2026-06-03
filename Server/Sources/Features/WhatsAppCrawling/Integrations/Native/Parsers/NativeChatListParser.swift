import Foundation

struct NativeChatListParser: ChatListParser {
    typealias Input = NativeParserContext
    typealias Output = [CrawledChat]

    let registry: NativeExtractionRegistry
    let runtime: AccessibilityRuntime

    func parse(_ input: NativeParserContext) async -> CrawlingResult<[CrawledChat]> {
        .failure(.notImplemented("Native chat list parsing is not wired yet."))
    }
}
