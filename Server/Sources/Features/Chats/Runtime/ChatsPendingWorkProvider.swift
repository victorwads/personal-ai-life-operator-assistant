import Foundation

struct ChatsPendingWorkProvider: PendingWorkProvider {
    private let repository: any ChatRepository
    private let permissionModeProvider: @MainActor () -> ChatPermissionMode

    init(
        repository: any ChatRepository,
        permissionModeProvider: @escaping @MainActor () -> ChatPermissionMode
    ) {
        self.repository = repository
        self.permissionModeProvider = permissionModeProvider
    }

    func pendingWorkSection() async throws -> PendingWorkSection? {
        let mode = await permissionModeProvider()
        let chats = try await repository.listUnhandledChats(limit: nil, permissionMode: mode)
        guard !chats.isEmpty else {
            return nil
        }

        return PendingWorkSection(
            title: "Unhandled chats",
            lines: chats.map { chat in
                let chatID = chat.id ?? "unknown"
                return "\(chat.title) (chatId: \(chatID))"
            }
        )
    }
}
