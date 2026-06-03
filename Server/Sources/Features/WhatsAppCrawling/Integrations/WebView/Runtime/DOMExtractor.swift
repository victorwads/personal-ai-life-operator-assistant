import Foundation

struct DefaultDOMExtractor: DOMExtractor {
    func extract(_ node: ExtractionNodeConfig) async -> CrawlingResult<ExtractedTree> {
        .failure(.notImplemented("DOM extraction is not wired yet."))
    }
}
