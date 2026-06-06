import Foundation

struct ServerLogEntry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let recordedAt: Date
    let kind: ServerLogKind
    let severity: ServerLogSeverity
    let title: String
    let summary: String
    let sessionId: String?
    let runId: String?
    let cycleNumber: Int?
    let toolCallId: String?
    let toolName: String?
    let durationMilliseconds: Double?
    let success: Bool?
    let inputPayload: String?
    let outputPayload: String?
    let errorPayload: String?
    let metadataPayload: String?
}

enum ServerLogKind: String, Codable, CaseIterable, Sendable {
    case sessionStarted
    case promptProcessingCompleted
    case reasoningCompleted
    case assistantOutputCompleted
    case toolCallCompleted
    case sessionCompleted
    case sessionFailed
}

enum ServerLogSeverity: String, Codable, CaseIterable, Sendable {
    case info
    case success
    case warning
    case error
}

struct ServerLogQuery: Sendable {
    var limit: Int = 1_000
    var runId: String?
    var sessionId: String?
    var kind: ServerLogKind?
    var severity: ServerLogSeverity?
    var success: Bool?
    var toolName: String?
}

enum ServerLogRepositoryChange: Equatable, Sendable {
    case inserted(String)
    case cleared
}
