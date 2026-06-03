import Foundation

protocol CrawlingInteractor {
    associatedtype Input
    associatedtype Output

    func execute(_ input: Input) async -> CrawlingResult<Output>
}
