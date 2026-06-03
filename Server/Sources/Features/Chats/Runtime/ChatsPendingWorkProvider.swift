import Foundation

struct ChatsPendingWorkProvider: PendingWorkProvider {
    private let repository: any ChatRepository

    init(repository: any ChatRepository) {
        self.repository = repository
    }

    func hasPendingWork() async throws -> Bool {
        !(try await repository.listUnhandledChats(limit: 1)).isEmpty
    }
}
