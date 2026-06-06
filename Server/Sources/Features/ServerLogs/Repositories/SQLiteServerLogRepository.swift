import Foundation
import SQLite3

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private final class ServerLogUpdateBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<ServerLogRepositoryChange>.Continuation] = [:]

    func stream() -> AsyncStream<ServerLogRepositoryChange> {
        let id = UUID()
        return AsyncStream { continuation in
            lock.lock()
            continuations[id] = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id: id)
            }
        }
    }

    func broadcast(_ change: ServerLogRepositoryChange) {
        lock.lock()
        let currentContinuations = Array(continuations.values)
        lock.unlock()

        for continuation in currentContinuations {
            continuation.yield(change)
        }
    }

    private func removeContinuation(id: UUID) {
        lock.lock()
        continuations.removeValue(forKey: id)
        lock.unlock()
    }
}

actor SQLiteServerLogRepository: ServerLogRepository {
    private let databaseURL: URL
    private let retentionLimit: Int
    private let fileManager: FileManager
    private let broadcaster = ServerLogUpdateBroadcaster()
    private var database: OpaquePointer?

    init(
        profileId: String,
        fileManager: FileManager = .default,
        databaseURL: URL? = nil,
        retentionLimit: Int = 10_000
    ) {
        self.fileManager = fileManager
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL(
            profileId: profileId,
            fileManager: fileManager
        )
        self.retentionLimit = retentionLimit
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    func insert(_ entry: ServerLogEntry) async throws {
        let database = try openDatabase()
        let sql = """
        INSERT INTO server_logs (
            id, created_at, kind, severity, title, summary, session_id, run_id,
            cycle_number, tool_call_id, tool_name, duration_milliseconds, success,
            input_payload, output_payload, error_payload, metadata_payload
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        let statement = try prepareStatement(database: database, sql: sql)
        defer { sqlite3_finalize(statement) }

        try bind(entry.id, at: 1, statement: statement)
        sqlite3_bind_double(statement, 2, entry.recordedAt.timeIntervalSince1970)
        try bind(entry.kind.rawValue, at: 3, statement: statement)
        try bind(entry.severity.rawValue, at: 4, statement: statement)
        try bind(entry.title, at: 5, statement: statement)
        try bind(entry.summary, at: 6, statement: statement)
        bind(entry.sessionId, at: 7, statement: statement)
        bind(entry.runId, at: 8, statement: statement)
        bind(entry.cycleNumber, at: 9, statement: statement)
        bind(entry.toolCallId, at: 10, statement: statement)
        bind(entry.toolName, at: 11, statement: statement)
        bind(entry.durationMilliseconds, at: 12, statement: statement)
        bind(entry.success, at: 13, statement: statement)
        bind(entry.inputPayload, at: 14, statement: statement)
        bind(entry.outputPayload, at: 15, statement: statement)
        bind(entry.errorPayload, at: 16, statement: statement)
        bind(entry.metadataPayload, at: 17, statement: statement)

        try step(statement: statement, database: database)
        try pruneIfNeeded(database: database)
        broadcaster.broadcast(.inserted(entry.id))
    }

    func list(_ query: ServerLogQuery) async throws -> [ServerLogEntry] {
        let database = try openDatabase()
        var clauses: [String] = []

        if query.runId != nil {
            clauses.append("run_id = ?")
        }
        if query.sessionId != nil {
            clauses.append("session_id = ?")
        }
        if query.kind != nil {
            clauses.append("kind = ?")
        }
        if query.severity != nil {
            clauses.append("severity = ?")
        }
        if query.success != nil {
            clauses.append("success = ?")
        }
        if query.toolName != nil {
            clauses.append("tool_name = ?")
        }

        let whereClause = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        let sql = """
        SELECT
            id, created_at, kind, severity, title, summary, session_id, run_id,
            cycle_number, tool_call_id, tool_name, duration_milliseconds, success,
            input_payload, output_payload, error_payload, metadata_payload
        FROM server_logs
        \(whereClause)
        ORDER BY created_at DESC, rowid DESC
        LIMIT ?;
        """

        let statement = try prepareStatement(database: database, sql: sql)
        defer { sqlite3_finalize(statement) }

        var parameterIndex: Int32 = 1
        if let runId = query.runId {
            try bind(runId, at: parameterIndex, statement: statement)
            parameterIndex += 1
        }
        if let sessionId = query.sessionId {
            try bind(sessionId, at: parameterIndex, statement: statement)
            parameterIndex += 1
        }
        if let kind = query.kind {
            try bind(kind.rawValue, at: parameterIndex, statement: statement)
            parameterIndex += 1
        }
        if let severity = query.severity {
            try bind(severity.rawValue, at: parameterIndex, statement: statement)
            parameterIndex += 1
        }
        if let success = query.success {
            bind(success, at: parameterIndex, statement: statement)
            parameterIndex += 1
        }
        if let toolName = query.toolName {
            try bind(toolName, at: parameterIndex, statement: statement)
            parameterIndex += 1
        }
        sqlite3_bind_int(statement, parameterIndex, Int32(max(query.limit, 1)))

        var entries: [ServerLogEntry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            entries.append(
                ServerLogEntry(
                    id: string(at: 0, statement: statement) ?? UUID().uuidString,
                    recordedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                    kind: ServerLogKind(rawValue: string(at: 2, statement: statement) ?? "") ?? .sessionFailed,
                    severity: ServerLogSeverity(rawValue: string(at: 3, statement: statement) ?? "") ?? .error,
                    title: string(at: 4, statement: statement) ?? "",
                    summary: string(at: 5, statement: statement) ?? "",
                    sessionId: string(at: 6, statement: statement),
                    runId: string(at: 7, statement: statement),
                    cycleNumber: int(at: 8, statement: statement),
                    toolCallId: string(at: 9, statement: statement),
                    toolName: string(at: 10, statement: statement),
                    durationMilliseconds: double(at: 11, statement: statement),
                    success: bool(at: 12, statement: statement),
                    inputPayload: string(at: 13, statement: statement),
                    outputPayload: string(at: 14, statement: statement),
                    errorPayload: string(at: 15, statement: statement),
                    metadataPayload: string(at: 16, statement: statement)
                )
            )
        }

        let resultCode = sqlite3_errcode(database)
        if resultCode != SQLITE_OK && resultCode != SQLITE_DONE {
            throw repositoryError(database: database)
        }

        return entries
    }

    func clear() async throws {
        let database = try openDatabase()
        try execute(database: database, sql: "DELETE FROM server_logs;")
        broadcaster.broadcast(.cleared)
    }

    func updates() async -> AsyncStream<ServerLogRepositoryChange> {
        broadcaster.stream()
    }

    private func openDatabase() throws -> OpaquePointer? {
        if let database {
            return database
        }

        let directoryURL = databaseURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        var openedDatabase: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(databaseURL.path, &openedDatabase, flags, nil) != SQLITE_OK {
            defer { sqlite3_close(openedDatabase) }
            throw repositoryError(database: openedDatabase)
        }

        self.database = openedDatabase
        try execute(database: openedDatabase, sql: "PRAGMA journal_mode=WAL;")
        try execute(database: openedDatabase, sql: "PRAGMA synchronous=NORMAL;")
        try execute(database: openedDatabase, sql: "PRAGMA temp_store=MEMORY;")
        try createSchema(database: openedDatabase)
        return openedDatabase
    }

    private func createSchema(database: OpaquePointer?) throws {
        try execute(
            database: database,
            sql: """
            CREATE TABLE IF NOT EXISTS server_logs (
                id TEXT PRIMARY KEY NOT NULL,
                created_at REAL NOT NULL,
                kind TEXT NOT NULL,
                severity TEXT NOT NULL,
                title TEXT NOT NULL,
                summary TEXT NOT NULL,
                session_id TEXT,
                run_id TEXT,
                cycle_number INTEGER,
                tool_call_id TEXT,
                tool_name TEXT,
                duration_milliseconds REAL,
                success INTEGER,
                input_payload TEXT,
                output_payload TEXT,
                error_payload TEXT,
                metadata_payload TEXT
            );
            """
        )
        try execute(database: database, sql: "CREATE INDEX IF NOT EXISTS idx_server_logs_created_at ON server_logs(created_at DESC);")
        try execute(database: database, sql: "CREATE INDEX IF NOT EXISTS idx_server_logs_kind ON server_logs(kind);")
        try execute(database: database, sql: "CREATE INDEX IF NOT EXISTS idx_server_logs_severity ON server_logs(severity);")
        try execute(database: database, sql: "CREATE INDEX IF NOT EXISTS idx_server_logs_tool_name ON server_logs(tool_name);")
        try execute(database: database, sql: "CREATE INDEX IF NOT EXISTS idx_server_logs_session_id ON server_logs(session_id);")
        try execute(database: database, sql: "CREATE INDEX IF NOT EXISTS idx_server_logs_run_id ON server_logs(run_id);")
    }

    private func pruneIfNeeded(database: OpaquePointer?) throws {
        guard retentionLimit > 0 else { return }
        try execute(
            database: database,
            sql: """
            DELETE FROM server_logs
            WHERE id IN (
                SELECT id
                FROM server_logs
                ORDER BY created_at DESC, rowid DESC
                LIMIT -1 OFFSET \(retentionLimit)
            );
            """
        )
    }

    private func execute(database: OpaquePointer?, sql: String) throws {
        if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
            throw repositoryError(database: database)
        }
    }

    private func prepareStatement(database: OpaquePointer?, sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            throw repositoryError(database: database)
        }
        return statement
    }

    private func step(statement: OpaquePointer?, database: OpaquePointer?) throws {
        if sqlite3_step(statement) != SQLITE_DONE {
            throw repositoryError(database: database)
        }
    }

    private func repositoryError(database: OpaquePointer?) -> NSError {
        let code = sqlite3_errcode(database)
        let message = String(cString: sqlite3_errmsg(database))
        return NSError(
            domain: "ServerLogs.SQLiteServerLogRepository",
            code: Int(code),
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func bind(_ value: String, at index: Int32, statement: OpaquePointer?) throws {
        guard sqlite3_bind_text(statement, index, value, -1, sqliteTransientDestructor) == SQLITE_OK else {
            throw repositoryError(database: database)
        }
    }

    private func bind(_ value: String?, at index: Int32, statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, value, -1, sqliteTransientDestructor)
    }

    private func bind(_ value: Int?, at index: Int32, statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_int64(statement, index, sqlite3_int64(value))
    }

    private func bind(_ value: Double?, at index: Int32, statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_double(statement, index, value)
    }

    private func bind(_ value: Bool?, at index: Int32, statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_int(statement, index, value ? 1 : 0)
    }

    private func string(at index: Int32, statement: OpaquePointer?) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    private func int(at index: Int32, statement: OpaquePointer?) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }

    private func double(at index: Int32, statement: OpaquePointer?) -> Double? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, index)
    }

    private func bool(at index: Int32, statement: OpaquePointer?) -> Bool? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int(statement, index) != 0
    }

    private static func defaultDatabaseURL(
        profileId: String,
        fileManager: FileManager
    ) -> URL {
        guard let rootURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("Application Support directory is unavailable.")
        }

        return rootURL
            .appendingPathComponent("AIAssistantHub", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(profileId, isDirectory: true)
            .appendingPathComponent("ServerLogs.sqlite", isDirectory: false)
    }
}
