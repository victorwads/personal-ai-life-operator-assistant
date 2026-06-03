import Foundation

final class ServerLogsService: @unchecked Sendable {
    private let repository: any ServerLogRepository

    init(repository: any ServerLogRepository) {
        self.repository = repository
    }

    func record(
        kind: ServerLogKind,
        severity: ServerLogSeverity,
        title: String,
        summary: String,
        sessionId: String? = nil,
        runId: String? = nil,
        cycleNumber: Int? = nil,
        toolCallId: String? = nil,
        toolName: String? = nil,
        durationMilliseconds: Double? = nil,
        success: Bool? = nil,
        inputPayload: String? = nil,
        outputPayload: String? = nil,
        errorPayload: String? = nil,
        metadataPayload: String? = nil
    ) {
        let entry = ServerLogEntry(
            id: UUID().uuidString,
            recordedAt: Date(),
            kind: kind,
            severity: severity,
            title: title,
            summary: summary,
            sessionId: sessionId,
            runId: runId,
            cycleNumber: cycleNumber,
            toolCallId: toolCallId,
            toolName: toolName,
            durationMilliseconds: durationMilliseconds,
            success: success,
            inputPayload: inputPayload,
            outputPayload: outputPayload,
            errorPayload: errorPayload,
            metadataPayload: metadataPayload
        )

        Task {
            try? await repository.insert(entry)
        }
    }

    func listRecent(limit: Int = 1_000) async throws -> [ServerLogEntry] {
        try await repository.list(ServerLogQuery(limit: limit))
    }

    func list(_ query: ServerLogQuery) async throws -> [ServerLogEntry] {
        try await repository.list(query)
    }

    func clear() async throws {
        try await repository.clear()
    }

    func updates() async -> AsyncStream<ServerLogRepositoryChange> {
        await repository.updates()
    }
}

enum ServerLogPayloadEncoder {
    static func jsonString<T: Encodable>(_ value: T?) -> String? {
        guard let value else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    static func jsonString(_ value: AIJSONValue?) -> String? {
        guard let value else { return nil }
        return try? value.jsonString(prettyPrinted: false)
    }

    static func objectString(_ pairs: [(String, AIJSONValue?)]) -> String? {
        let object = pairs.reduce(into: [String: AIJSONValue]()) { partialResult, pair in
            if let value = pair.1 {
                partialResult[pair.0] = value
            }
        }

        guard !object.isEmpty else { return nil }
        return try? AIJSONValue.object(object).jsonString(prettyPrinted: false)
    }
}
