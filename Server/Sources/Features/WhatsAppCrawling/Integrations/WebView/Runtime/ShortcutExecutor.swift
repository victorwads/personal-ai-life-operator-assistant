import Foundation

struct DefaultShortcutExecutor: ShortcutExecutor {
    func execute(_ shortcut: ShortcutConfig) async -> CrawlingResult<Void> {
        .failure(.notImplemented("Shortcut execution is not wired yet."))
    }
}
