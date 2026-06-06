import Foundation

struct ClientInteractionRequest: PersistableModel, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case ask
        case speak
    }

    enum Status: String, Codable, Sendable {
        case initialized
        case speaking
        case waitingUser // Already spoked
        case waitingAgent
        case completed
        case cancelled
    }

    enum Device: String, Codable, Sendable {
        case desktop
        case mobile
    }

    @DocumentID var id: String?

    var issueId: String?
    var kind: Kind
    var status: Status = .initialized

    var promptText: String
    var responseText: String?

    var device: Device?
}
