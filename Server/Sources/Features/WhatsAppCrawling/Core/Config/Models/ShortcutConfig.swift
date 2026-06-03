import Foundation

struct ShortcutConfig: Decodable, Equatable, Sendable {
    let modifiers: [String]
    let key: String
}
