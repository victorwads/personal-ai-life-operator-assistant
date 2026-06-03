import Foundation

struct AIRunToolCallState: Identifiable, Encodable {
    enum Status: String, Encodable {
        case started
        case argumentsStreaming
        case argumentsReady
        case executing
        case completed
        case failed
        case cancelled
    }

    let id: String
    var name: String
    var icon: String?
    var argumentsJSON: String
    var responseText: String?
    var errorText: String?
    var status: Status
    let startedAt: Date
    var endedAt: Date?
    var rawEventSummary: String

    var argumentsPreview: String {
        let compact = argumentsJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return "No arguments yet" }
        return compact.count > 140 ? String(compact.prefix(140)) + "..." : compact
    }

    var durationText: String {
        guard let endedAt else { return "-" }
        return String(format: "%.2fs", endedAt.timeIntervalSince(startedAt))
    }
}
