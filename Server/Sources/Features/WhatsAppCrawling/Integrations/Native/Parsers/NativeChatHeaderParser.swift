import Foundation

struct NativeChatHeaderParser: ChatHeaderParser {
    typealias Input = NativeParserContext
    typealias Output = CrawledChatHeader

    let registry: NativeExtractionRegistry
    let runtime: AccessibilityRuntime

    func parse(_ input: NativeParserContext) async -> CrawlingResult<CrawledChatHeader> {
        .failure(.notImplemented("Native chat header parsing is not wired yet."))
    }
}
