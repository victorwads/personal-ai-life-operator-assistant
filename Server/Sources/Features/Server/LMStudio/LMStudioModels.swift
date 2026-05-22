import Foundation

enum LMStudioSessionState: Equatable {
    case idle
    case refreshingModels
    case starting
    case running
    case pausing
    case paused
    case completed
    case failed(message: String)
}

enum LMStudioEventSeverity: String, Hashable, Sendable {
    case neutral
    case progress
    case success
    case warning
    case error
    case tool
}

struct LMStudioEventRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let type: String
    let title: String
    let detail: String?
    let toolName: String?
    let severity: LMStudioEventSeverity
    let progress: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: String,
        title: String,
        detail: String? = nil,
        toolName: String? = nil,
        severity: LMStudioEventSeverity = .neutral,
        progress: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.detail = detail
        self.toolName = toolName
        self.severity = severity
        self.progress = progress
    }
}

struct LMStudioModelListResponse: Decodable, Sendable {
    let models: [LMStudioModelSummary]
}

struct LMStudioModelSummary: Identifiable, Hashable, Decodable, Sendable {
    // Keep this model intentionally minimal: we only need the identity key and a
    // human-friendly label for selection. Extra fields vary across LM Studio builds
    // and can cause decoding failures when missing.
    let key: String
    let displayName: String

    var id: String { key }
}

struct LMStudioChatRequestBody: Encodable, Sendable {
    let model: String
    let input: String
    let systemPrompt: String?
    let integrations: [LMStudioIntegration]?
    let stream: Bool
    let store: Bool?
    let previousResponseID: String?
    let contextLength: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case systemPrompt = "system_prompt"
        case integrations
        case stream
        case store
        case previousResponseID = "previous_response_id"
        case contextLength = "context_length"
    }
}

enum LMStudioIntegration: Encodable, Sendable {
    case plugin(id: String, allowedTools: [String]? = nil)
    case ephemeralMCP(
        serverLabel: String,
        serverURL: String,
        allowedTools: [String]?,
        headers: [String: String]?,
        timeout: Int?
    )

    func encode(to encoder: Encoder) throws {
        switch self {
        case .plugin(let id, let allowedTools):
            if let allowedTools {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("plugin", forKey: .type)
                try container.encode(id, forKey: .id)
                try container.encode(allowedTools, forKey: .allowedTools)
            } else {
                var container = encoder.singleValueContainer()
                try container.encode(id)
            }
        case .ephemeralMCP(let serverLabel, let serverURL, let allowedTools, let headers, let timeout):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("ephemeral_mcp", forKey: .type)
            try container.encode(serverLabel, forKey: .serverLabel)
            try container.encode(serverURL, forKey: .serverURL)
            try container.encodeIfPresent(allowedTools, forKey: .allowedTools)
            try container.encodeIfPresent(headers, forKey: .headers)
            try container.encodeIfPresent(timeout, forKey: .timeout)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case serverLabel = "server_label"
        case serverURL = "server_url"
        case allowedTools = "allowed_tools"
        case headers
        case timeout
    }
}

struct LMStudioChatFinalResult {
    let modelInstanceID: String?
    let responseID: String?
    let finalText: String
    let rawOutputItems: [[String: Any]]?
}
