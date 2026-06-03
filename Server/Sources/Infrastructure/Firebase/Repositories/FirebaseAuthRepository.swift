import Foundation
import AppKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

enum FirebaseAuthRepositoryError: LocalizedError {
    case firebaseNotConfigured
    case missingClientId
    case signInAlreadyInProgress
    case missingPresentingWindow
    case missingGoogleIDToken
    case googleSignInFailed(String)
    case firebaseSignInFailed(String)
    case signOutFailed

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: return "Firebase is not configured."
        case .missingClientId: return "Missing Google Client ID. Check GoogleService-Info.plist."
        case .signInAlreadyInProgress: return "A Google sign-in is already in progress."
        case .missingPresentingWindow: return "Unable to find a window for Google sign-in."
        case .missingGoogleIDToken: return "Google sign-in did not return an ID token."
        case .googleSignInFailed(let message): return "Google sign-in failed: \(message)"
        case .firebaseSignInFailed(let message): return "Firebase sign-in failed: \(message)"
        case .signOutFailed: return "Unable to sign out."
        }
    }
}

actor FirebaseAuthRepository: AuthRepository {
    private struct GoogleSignInTokens: Sendable {
        let idToken: String
        let accessToken: String
    }

    private var isSigningIn = false

    init() {}

    func currentSession() async -> AuthSession? {
        Auth.auth().currentUser.map(Self.session)
    }

    func signInWithGoogle() async throws -> AuthSession {
        guard !isSigningIn else {
            throw FirebaseAuthRepositoryError.signInAlreadyInProgress
        }

        guard let firebaseApp = FirebaseApp.app() else {
            throw FirebaseAuthRepositoryError.firebaseNotConfigured
        }

        guard let clientId = firebaseApp.options.clientID, !clientId.isEmpty else {
            throw FirebaseAuthRepositoryError.missingClientId
        }

        isSigningIn = true
        defer { isSigningIn = false }

        let tokens = try await Self.signInWithGoogleSDK(clientId: clientId)
        let credential = GoogleAuthProvider.credential(
            withIDToken: tokens.idToken,
            accessToken: tokens.accessToken
        )

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            return Self.session(from: authResult.user)
        } catch {
            throw FirebaseAuthRepositoryError.firebaseSignInFailed(error.localizedDescription)
        }
    }

    func signOut() async throws {
        do {
            await MainActor.run {
                GIDSignIn.sharedInstance.signOut()
            }
            try Auth.auth().signOut()
        } catch {
            throw FirebaseAuthRepositoryError.signOutFailed
        }
    }

    func handleOpenURL(_ url: URL) async throws -> AuthSession? {
        let handled = await MainActor.run {
            GIDSignIn.sharedInstance.handle(url)
        }

        guard handled else {
            return nil
        }

        return await currentSession()
    }

    private static func session(from user: User) -> AuthSession {
        AuthSession(
            user: AuthUser(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
                photoURL: user.photoURL?.absoluteString
            )
        )
    }

    @MainActor
    private static func signInWithGoogleSDK(clientId: String) async throws -> GoogleSignInTokens {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)

        let presentingWindow = try presentingWindow()
        let result: GIDSignInResult

        do {
            result = try await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow) { result, error in
                    if let error {
                        continuation.resume(throwing: FirebaseAuthRepositoryError.googleSignInFailed(error.localizedDescription))
                        return
                    }

                    guard let result else {
                        continuation.resume(throwing: FirebaseAuthRepositoryError.googleSignInFailed("No sign-in result was returned."))
                        return
                    }

                    continuation.resume(returning: result)
                }
            }
        } catch let error as FirebaseAuthRepositoryError {
            throw error
        } catch {
            throw FirebaseAuthRepositoryError.googleSignInFailed(error.localizedDescription)
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw FirebaseAuthRepositoryError.missingGoogleIDToken
        }

        return GoogleSignInTokens(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }

    @MainActor
    private static func presentingWindow() throws -> NSWindow {
        if let keyWindow = NSApplication.shared.keyWindow {
            return keyWindow
        }

        if let mainWindow = NSApplication.shared.mainWindow {
            return mainWindow
        }

        if let visibleWindow = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            return visibleWindow
        }

        throw FirebaseAuthRepositoryError.missingPresentingWindow
    }
}
