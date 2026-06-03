import Foundation

struct AIRequestedToolCall: Equatable, Sendable {
    let id: String
    let name: String
    let argumentsJSON: String
}
