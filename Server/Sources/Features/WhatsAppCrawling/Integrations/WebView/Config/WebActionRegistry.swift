import Foundation

struct WebActionRegistry {
    let shortcuts: [String: ShortcutConfig]

    func shortcut(named name: String) -> ShortcutConfig? {
        shortcuts[name]
    }
}
