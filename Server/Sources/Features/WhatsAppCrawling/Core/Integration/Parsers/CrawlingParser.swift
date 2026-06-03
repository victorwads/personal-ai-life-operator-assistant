import Foundation

struct ParserContext<Config, Runtime> {
    let config: Config
    let flowState: FlowState
    let runtime: Runtime
}

protocol CrawlingParser {
    associatedtype Input
    associatedtype Output

    func parse(_ input: Input) async -> CrawlingResult<Output>
}
