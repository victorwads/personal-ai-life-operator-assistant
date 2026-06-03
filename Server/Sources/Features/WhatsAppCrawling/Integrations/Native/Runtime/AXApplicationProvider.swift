import Foundation

protocol AXApplicationProvider {
    func currentApplicationIdentifier() async -> CrawlingResult<String>
}
