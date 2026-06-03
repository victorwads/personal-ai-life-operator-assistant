import Foundation

protocol AXActionExecutor {
    func performShortcut(_ shortcut: ShortcutConfig) async -> CrawlingResult<Void>
}
