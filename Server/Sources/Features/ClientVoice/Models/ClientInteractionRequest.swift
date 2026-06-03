import Foundation

struct ClientInteractionRequest: PersistableModel, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case ask
        case speak
    }

    enum Status: String, Codable, Sendable {
        case initialized
        case waitingAgent
        case completed
        case cancelled
    }

    enum Source: String, Codable, Sendable {
        case desktop
        case mobile
    }

    @DocumentID var id: String?

    var issueId: String
    var kind: Kind
    var status: Status = .initialized

    var promptText: String
    var responseText: String?

    var source: Source?
}
