import Foundation

protocol ConfigParser {
    associatedtype Output

    func parse(_ yaml: String) async -> CrawlingResult<Output>
}
