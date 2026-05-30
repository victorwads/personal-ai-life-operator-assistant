import Foundation

protocol SettingsRepository {
    func loadScope(_ scopeName: String) async throws -> SettingsDocument
    func loadAllScopes() async throws -> [SettingsDocument]
    func saveScope(_ scopeName: String, values: [String: String]) async throws
    func getValue(scopeName: String, key: String) async throws -> String?
    func setValue(scopeName: String, key: String, value: String) async throws
    func deleteValue(scopeName: String, key: String) async throws
    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken
    func observeAllScopes(_ listener: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken
}
