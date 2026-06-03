import Foundation

protocol ServerLogRepository: Sendable {
    func insert(_ entry: ServerLogEntry) async throws
    func list(_ query: ServerLogQuery) async throws -> [ServerLogEntry]
    func clear() async throws
    func updates() async -> AsyncStream<ServerLogRepositoryChange>
}
