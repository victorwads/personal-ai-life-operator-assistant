import Foundation

@MainActor
final class AuthStateController: ObservableObject {
    @Published private(set) var state: AuthState = .loading
    @Published private(set) var currentSession: AuthSession?

    private let repository: AuthRepository

    init(repository: AuthRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        currentSession = await repository.currentSession()

        if currentSession != nil {
            state = .authenticated
        } else {
            state = .unauthenticated
        }
    }

    func signInWithGoogle() async {
        state = .loading

        do {
            let session = try await repository.signInWithGoogle()
            currentSession = session
            state = .authenticated
        } catch {
            currentSession = nil
            state = .failed(message: Self.describeError(error))
        }
    }

    func signOut() async {
        do {
            try await repository.signOut()
            currentSession = nil
            state = .unauthenticated
        } catch {
            state = .failed(message: Self.describeError(error))
        }
    }

    func handleOpenURL(_ url: URL) async {
        do {
            if let session = try await repository.handleOpenURL(url) {
                currentSession = session
                state = .authenticated
            }
        } catch {
            currentSession = nil
            state = .failed(message: Self.describeError(error))
        }
    }

    private static func describeError(_ error: Error) -> String {
        let nsError = error as NSError
        var parts: [String] = []
        parts.append(nsError.localizedDescription)

        if let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !failureReason.isEmpty {
            parts.append("Reason: \(failureReason)")
        }

        if let recoverySuggestion = nsError.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String, !recoverySuggestion.isEmpty {
            parts.append("Suggestion: \(recoverySuggestion)")
        }

        if parts.count == 1 {
            return parts[0]
        }

        return parts.joined(separator: "\n")
    }
}
