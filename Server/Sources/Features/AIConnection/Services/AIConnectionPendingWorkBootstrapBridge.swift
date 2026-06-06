import Foundation

@MainActor
final class AIConnectionPendingWorkBootstrapBridge {
    private let snapshotProvider: @MainActor () async throws -> PendingWorkSnapshot

    init(
        snapshotProvider: @escaping @MainActor () async throws -> PendingWorkSnapshot
    ) {
        self.snapshotProvider = snapshotProvider
    }

    func bootstrapMessage() async -> AIConversationMessage? {
        do {
            let snapshot = try await snapshotProvider()
            guard let text = PendingWorkTextRenderer.bootstrapText(for: snapshot) else {
                return nil
            }

            return AIConversationMessage(role: .user, content: text)
        } catch {
            print("AIConnection pending work bootstrap failed: \(error.localizedDescription)")
            return nil
        }
    }
}
