import Foundation

struct Memory: PersistableModel, Equatable, Sendable {
    var id: String?
    var key: String
    var value: String
}
