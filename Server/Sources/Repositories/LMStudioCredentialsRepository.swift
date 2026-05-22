import Foundation

@MainActor
final class LMStudioCredentialsRepository {
    static let shared = LMStudioCredentialsRepository()

    private let store: KeychainDataStore

    init(store: KeychainDataStore = KeychainDataStore(service: "dev.wads.AssistantMCPServer", account: "lm-studio-api-token")) {
        self.store = store
    }

    func loadAPIToken() throws -> String {
        guard let data = try store.loadData() else {
            return ""
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func saveAPIToken(_ token: String) throws {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            try store.deleteData()
            return
        }

        guard let data = trimmedToken.data(using: .utf8) else {
            return
        }

        try store.saveData(data)
    }
}
