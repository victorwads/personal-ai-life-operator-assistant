import XCTest
@testable import AIAssistantHub

final class SQLiteServerLogRepositoryTests: XCTestCase {
    func testInsertListNewestFirstAndClear() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("ServerLogs.sqlite", isDirectory: false)
        let repository = SQLiteServerLogRepository(
            profileId: "test-profile",
            databaseURL: databaseURL,
            retentionLimit: 100
        )

        try await repository.insert(
            ServerLogEntry(
                id: "older",
                recordedAt: Date(timeIntervalSince1970: 100),
                kind: .sessionStarted,
                severity: .info,
                title: "Older",
                summary: "Older summary",
                sessionId: "session-1",
                runId: "run-1",
                cycleNumber: 1,
                toolCallId: nil,
                toolName: nil,
                durationMilliseconds: nil,
                success: nil,
                inputPayload: nil,
                outputPayload: nil,
                errorPayload: nil,
                metadataPayload: nil
            )
        )

        try await repository.insert(
            ServerLogEntry(
                id: "newer",
                recordedAt: Date(timeIntervalSince1970: 200),
                kind: .toolCallCompleted,
                severity: .success,
                title: "Newer",
                summary: "Newer summary",
                sessionId: "session-1",
                runId: "run-1",
                cycleNumber: 1,
                toolCallId: "tool-1",
                toolName: "get_current_datetime",
                durationMilliseconds: 12,
                success: true,
                inputPayload: "{}",
                outputPayload: "{\"ok\":true}",
                errorPayload: nil,
                metadataPayload: nil
            )
        )

        let allEntries = try await repository.list(ServerLogQuery(limit: 10))
        XCTAssertEqual(allEntries.map(\.id), ["newer", "older"])

        let toolEntries = try await repository.list(
            ServerLogQuery(limit: 10, toolName: "get_current_datetime")
        )
        XCTAssertEqual(toolEntries.map(\.id), ["newer"])

        try await repository.clear()

        let clearedEntries = try await repository.list(ServerLogQuery(limit: 10))
        XCTAssertTrue(clearedEntries.isEmpty)
    }

    func testUpdatesEmitOnInsert() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("ServerLogs.sqlite", isDirectory: false)
        let repository = SQLiteServerLogRepository(
            profileId: "test-profile",
            databaseURL: databaseURL,
            retentionLimit: 100
        )
        let updates = await repository.updates()

        let updateTask = Task { () -> ServerLogRepositoryChange? in
            for await update in updates {
                return update
            }
            return nil
        }

        try await repository.insert(
            ServerLogEntry(
                id: "entry-1",
                recordedAt: Date(),
                kind: .sessionStarted,
                severity: .info,
                title: "Started",
                summary: "Started summary",
                sessionId: "session-1",
                runId: "run-1",
                cycleNumber: nil,
                toolCallId: nil,
                toolName: nil,
                durationMilliseconds: nil,
                success: nil,
                inputPayload: nil,
                outputPayload: nil,
                errorPayload: nil,
                metadataPayload: nil
            )
        )

        let update = try await waitForUpdate(from: updateTask)
        XCTAssertEqual(update, .inserted("entry-1"))
    }

    private func waitForUpdate(
        from task: Task<ServerLogRepositoryChange?, Never>,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async throws -> ServerLogRepositoryChange {
        let result = try await withThrowingTaskGroup(of: ServerLogRepositoryChange?.self) { group in
            group.addTask {
                await task.value
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }

            let first = try await group.next() ?? nil
            group.cancelAll()
            return first
        }

        return try XCTUnwrap(result)
    }
}
