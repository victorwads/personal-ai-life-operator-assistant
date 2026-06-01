import Foundation

struct ClientInteractionRequest: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var issueId: String
    var kind: ClientInteractionKind
    var status: ClientInteractionStatus
    var clientPresenceAtCreation: ClientPresenceState
    var promptText: String
    var responseText: String?
    var requestedAt: Date?
    var lastStatusChangeAt: Date?
    var deliveredAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
    var failedAt: Date?
    var errorMessage: String?
    var source: ClientInteractionSource
    var targetDeviceId: String?
    var answeredByDeviceId: String?
    var metadata: [String: String]

    init(
        id: String? = nil,
        issueId: String,
        kind: ClientInteractionKind,
        status: ClientInteractionStatus = .pending,
        clientPresenceAtCreation: ClientPresenceState = .unknown,
        promptText: String,
        responseText: String? = nil,
        requestedAt: Date? = nil,
        lastStatusChangeAt: Date? = nil,
        deliveredAt: Date? = nil,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil,
        failedAt: Date? = nil,
        errorMessage: String? = nil,
        source: ClientInteractionSource = .unknown,
        targetDeviceId: String? = nil,
        answeredByDeviceId: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.issueId = issueId
        self.kind = kind
        self.status = status
        self.clientPresenceAtCreation = clientPresenceAtCreation
        self.promptText = promptText
        self.responseText = responseText
        self.requestedAt = requestedAt
        self.lastStatusChangeAt = lastStatusChangeAt
        self.deliveredAt = deliveredAt
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
        self.failedAt = failedAt
        self.errorMessage = errorMessage
        self.source = source
        self.targetDeviceId = targetDeviceId
        self.answeredByDeviceId = answeredByDeviceId
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        issueId = try container.decodeIfPresent(String.self, forKey: .issueId) ?? ""
        kind = try container.decodeIfPresent(ClientInteractionKind.self, forKey: .kind) ?? .ask
        status = try container.decodeIfPresent(ClientInteractionStatus.self, forKey: .status) ?? .pending
        clientPresenceAtCreation = try container.decodeIfPresent(ClientPresenceState.self, forKey: .clientPresenceAtCreation) ?? .unknown
        promptText = try container.decodeIfPresent(String.self, forKey: .promptText) ?? ""
        responseText = try container.decodeIfPresent(String.self, forKey: .responseText)
        requestedAt = try container.decodeIfPresent(Date.self, forKey: .requestedAt)
        lastStatusChangeAt = try container.decodeIfPresent(Date.self, forKey: .lastStatusChangeAt)
        deliveredAt = try container.decodeIfPresent(Date.self, forKey: .deliveredAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        cancelledAt = try container.decodeIfPresent(Date.self, forKey: .cancelledAt)
        failedAt = try container.decodeIfPresent(Date.self, forKey: .failedAt)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        source = try container.decodeIfPresent(ClientInteractionSource.self, forKey: .source) ?? .unknown
        targetDeviceId = try container.decodeIfPresent(String.self, forKey: .targetDeviceId)
        answeredByDeviceId = try container.decodeIfPresent(String.self, forKey: .answeredByDeviceId)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}

enum ClientInteractionKind: String, Codable, Equatable, Sendable, CaseIterable {
    case ask
    case speak

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .ask
    }
}

enum ClientInteractionStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case pending
    case delivered
    case completed
    case cancelled
    case failed

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .pending
    }
}

enum ClientPresenceState: String, Codable, Equatable, Sendable, CaseIterable {
    case present
    case absent
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}

enum ClientInteractionSource: String, Codable, Equatable, Sendable, CaseIterable {
    case desktop
    case mobile
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}
