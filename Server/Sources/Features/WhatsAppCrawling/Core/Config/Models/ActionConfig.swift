import Foundation

struct ActionConfig: Decodable, Equatable, Sendable {
    let shortcuts: [String: ShortcutConfig]
}
