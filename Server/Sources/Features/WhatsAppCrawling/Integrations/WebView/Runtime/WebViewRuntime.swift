import Foundation

protocol JavaScriptExecutor {
    func evaluate(_ script: String) async -> CrawlingResult<String>
}

protocol DOMExtractor {
    func extract(_ node: ExtractionNodeConfig) async -> CrawlingResult<ExtractedTree>
}

protocol ShortcutExecutor {
    func execute(_ shortcut: ShortcutConfig) async -> CrawlingResult<Void>
}

struct WebViewRuntime {
    let javascriptExecutor: any JavaScriptExecutor
    let domExtractor: any DOMExtractor
    let shortcutExecutor: any ShortcutExecutor
}
