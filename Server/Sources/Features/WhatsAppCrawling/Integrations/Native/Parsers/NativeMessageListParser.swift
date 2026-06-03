import Foundation

struct NativeMessageListParser: MessageListParser {
    typealias Input = NativeParserContext
    typealias Output = [CrawledMessage]

    let registry: NativeExtractionRegistry
    let runtime: AccessibilityRuntime

    func parse(_ input: NativeParserContext) async -> CrawlingResult<[CrawledMessage]> {
        .failure(.notImplemented("Native message list parsing is not wired yet."))
    }
}
