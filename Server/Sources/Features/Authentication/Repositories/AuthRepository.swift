import Foundation

protocol AuthRepository {
    func currentSession() async -> AuthSession?
    func signInWithGoogle() async throws -> AuthSession
    func signOut() async throws
    func handleOpenURL(_ url: URL) async throws -> AuthSession?
}
