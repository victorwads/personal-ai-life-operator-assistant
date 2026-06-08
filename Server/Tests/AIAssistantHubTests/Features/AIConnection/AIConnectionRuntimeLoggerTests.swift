import XCTest
@testable import AIAssistantHub

@MainActor
final class AIConnectionRuntimeLoggerTests: XCTestCase {
    func testSessionCompletedMetadataIncludesTokenUsage() async throws {
        let repository = FakeServerLogRepository()
        let service = ServerLogsService(repository: repository)
        let logger = AIConnectionRuntimeLogger(
            errorLogStore: AIConnectionErrorLogStore(),
            serverLogsProvider: { service }
        )

        var state = AIConnectionRuntimeState.initial(systemPrompt: "System prompt")
        state.runId = UUID()
        state.startedAt = Date(timeIntervalSince1970: 100)
        state.usage.inputTokens = 120
        state.usage.outputTokens = 45
        state.usage.reasoningTokens = 8
        state.usage.cachedInputTokens = 6
        state.usage.totalTokens = 173
        state.usage.isInputTokensEstimated = true
        state.usage.isOutputTokensEstimated = false
        state.usage.tokensPerSecond = 9.5
        state.usage.timeToFirstToken = 1.25
        state.usage.runDuration = 5.0

        logger.logCycleCompleted(
            state: state,
            outcome: .completed,
            cycleNumber: 1,
            requestContext: nil
        )

        let entry = try await waitForEntry(in: repository)
        XCTAssertEqual(entry.kind, .sessionCompleted)
        XCTAssertTrue(entry.metadataPayload?.contains("\"inputTokens\":120") == true)
        XCTAssertTrue(entry.metadataPayload?.contains("\"outputTokens\":45") == true)
        XCTAssertTrue(entry.metadataPayload?.contains("\"reasoningTokens\":8") == true)
        XCTAssertTrue(entry.metadataPayload?.contains("\"cachedInputTokens\":6") == true)
        XCTAssertTrue(entry.metadataPayload?.contains("\"totalTokens\":173") == true)
        XCTAssertTrue(entry.metadataPayload?.contains("\"isInputTokensEstimated\":true") == true)
        XCTAssertTrue(entry.metadataPayload?.contains("\"isOutputTokensEstimated\":false") == true)
    }

    private func waitForEntry(in repository: FakeServerLogRepository) async throws -> ServerLogEntry {
        for _ in 0..<50 {
            if let entry = await repository.entries.first {
                return entry
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        throw NSError(
            domain: "AIConnectionRuntimeLoggerTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for server log entry."]
        )
    }
}

private actor FakeServerLogRepository: ServerLogRepository {
    private(set) var entries: [ServerLogEntry] = []

    func insert(_ entry: ServerLogEntry) async throws {
        entries.append(entry)
    }

    func list(_ query: ServerLogQuery) async throws -> [ServerLogEntry] {
        entries
    }

    func clear() async throws {
        entries.removeAll()
    }

    func updates() async -> AsyncStream<ServerLogRepositoryChange> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
