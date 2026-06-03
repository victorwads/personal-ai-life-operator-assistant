import Foundation

struct DefaultJavaScriptExecutor: JavaScriptExecutor {
    func evaluate(_ script: String) async -> CrawlingResult<String> {
        .failure(.notImplemented("JavaScript execution is not wired yet."))
    }
}
