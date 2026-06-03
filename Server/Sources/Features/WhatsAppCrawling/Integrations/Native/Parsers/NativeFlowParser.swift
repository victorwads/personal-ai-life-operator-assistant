import Foundation

struct NativeFlowParser: FlowParser {
    typealias Input = ParserContext<NativeFlowRegistry, AccessibilityRuntime>
    typealias Output = FlowState

    let registry: NativeFlowRegistry
    let runtime: AccessibilityRuntime

    func parse(_ input: Input) async -> CrawlingResult<FlowState> {
        .failure(.notImplemented("Native flow detection is not wired yet."))
    }
}
