import Foundation

protocol AXElementFinder {
    func findElements(matching node: ExtractionNodeConfig) async -> CrawlingResult<[ExtractedNode]>
}
