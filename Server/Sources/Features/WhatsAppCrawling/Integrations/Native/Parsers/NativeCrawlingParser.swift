import Foundation

typealias NativeParserContext = ParserContext<NativeExtractionRegistry, AccessibilityRuntime>

struct NativeCrawlingParser: CrawlingParser {
    typealias Input = NativeParserContext
    typealias Output = ExtractedTree

    let registry: NativeExtractionRegistry
    let runtime: AccessibilityRuntime

    func parse(_ input: NativeParserContext) async -> CrawlingResult<ExtractedTree> {
        .failure(.notImplemented("Native extraction parsing is not wired yet."))
    }
}
