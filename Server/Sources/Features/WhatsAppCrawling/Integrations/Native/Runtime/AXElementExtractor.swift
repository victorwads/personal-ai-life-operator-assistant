import Foundation

protocol AXElementExtractor {
    func extractTree(from node: ExtractionNodeConfig) async -> CrawlingResult<ExtractedTree>
}
