import Foundation
import AppKit
import CryptoKit
import FirebaseAuth
import FirebaseCore

enum FirebaseAuthRepositoryError: LocalizedError {
    case firebaseNotConfigured
    case missingClientId
    case signInAlreadyInProgress
    case unableToOpenBrowser
    case invalidCallbackURL
    case oauthError(String)
    case missingAuthorizationCode
    case invalidState
    case tokenExchangeFailed(String)
    case signOutFailed

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not configured."
        case .missingClientId:
            return "Missing Google Client ID. Check GoogleService-Info.plist."
        case .signInAlreadyInProgress:
            return "A Google sign-in is already in progress."
        case .unableToOpenBrowser:
            return "Unable to open the browser for Google sign-in."
        case .invalidCallbackURL:
            return "Google sign-in returned an invalid callback URL."
        case .oauthError(let message):
            return "Google sign-in failed: \(message)"
        case .missingAuthorizationCode:
            return "Google sign-in did not return an authorization code."
        case .invalidState:
            return "Google sign-in returned an invalid state."
        case .tokenExchangeFailed(let body):
            return "Google token exchange failed: \(body)"
        case .signOutFailed:
            return "Unable to sign out."
        }
    }
}

actor FirebaseAuthRepository: AuthRepository {
    private struct PendingOAuthRequest {
        let clientId: String
        let state: String
        let codeVerifier: String
        let redirectURI: URL
        let authorizationURL: URL
        let redirectScheme: String
    }

    private struct GoogleTokenResponse: Decodable {
        let accessToken: String
        let idToken: String

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case idToken = "id_token"
        }
    }

    private var pendingOAuthRequest: PendingOAuthRequest?
    private var pendingContinuation: CheckedContinuation<AuthSession, Error>?

    init() {}

    func currentSession() async -> AuthSession? {
        guard FirebaseApp.app() != nil else {
            return nil
        }

        guard let user = Auth.auth().currentUser else {
            return nil
        }

        return AuthSession(
            user: AuthUser(
                uid: user.uid,
                email: user.email,
                displayName: user.displayName,
                photoURL: user.photoURL?.absoluteString
            )
        )
    }

    func signInWithGoogle() async throws -> AuthSession {
        guard FirebaseApp.app() != nil else {
            throw FirebaseAuthRepositoryError.firebaseNotConfigured
        }

        if pendingContinuation != nil {
            throw FirebaseAuthRepositoryError.signInAlreadyInProgress
        }

        guard let clientId = FirebaseApp.app()?.options.clientID, !clientId.isEmpty else {
            throw FirebaseAuthRepositoryError.missingClientId
        }

        let request = try makeOAuthRequest(clientId: clientId)
        pendingOAuthRequest = request

        let opened = await MainActor.run { NSWorkspace.shared.open(request.authorizationURL) }
        guard opened else {
            pendingOAuthRequest = nil
            throw FirebaseAuthRepositoryError.unableToOpenBrowser
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuation = continuation
        }
    }

    func signOut() async throws {
        guard FirebaseApp.app() != nil else {
            throw FirebaseAuthRepositoryError.firebaseNotConfigured
        }

        do {
            try Auth.auth().signOut()
        } catch {
            throw FirebaseAuthRepositoryError.signOutFailed
        }
    }

    func handleOpenURL(_ url: URL) async throws -> AuthSession? {
        guard FirebaseApp.app() != nil else {
            throw FirebaseAuthRepositoryError.firebaseNotConfigured
        }

        guard let pending = pendingOAuthRequest, url.scheme == pending.redirectScheme else {
            return nil
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw FirebaseAuthRepositoryError.invalidCallbackURL
        }

        let queryItems = components.queryItems ?? []

        if let errorValue = queryItems.first(where: { $0.name == "error" })?.value {
            pendingOAuthRequest = nil
            pendingContinuation?.resume(throwing: FirebaseAuthRepositoryError.oauthError(errorValue))
            pendingContinuation = nil
            throw FirebaseAuthRepositoryError.oauthError(errorValue)
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw FirebaseAuthRepositoryError.missingAuthorizationCode
        }

        guard let returnedState = queryItems.first(where: { $0.name == "state" })?.value, returnedState == pending.state else {
            throw FirebaseAuthRepositoryError.invalidState
        }

        pendingOAuthRequest = nil

        let tokenResponse = try await exchangeAuthorizationCode(
            code,
            clientId: pending.clientId,
            codeVerifier: pending.codeVerifier,
            redirectURI: pending.redirectURI
        )

        let session = try await signInToFirebase(idToken: tokenResponse.idToken, accessToken: tokenResponse.accessToken)
        pendingContinuation?.resume(returning: session)
        pendingContinuation = nil
        return session
    }

    private func makeOAuthRequest(clientId: String) throws -> PendingOAuthRequest {
        let state = Self.randomURLSafeString(byteCount: 16)
        let codeVerifier = Self.randomURLSafeString(byteCount: 32)
        let codeChallenge = Self.codeChallenge(for: codeVerifier)

        let redirectScheme = try googleReversedClientIdScheme()

        let redirectURI = URL(string: "\(redirectScheme):/oauthredirect")!

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authorizationURL = components.url else {
            throw FirebaseAuthRepositoryError.invalidCallbackURL
        }

        return PendingOAuthRequest(
            clientId: clientId,
            state: state,
            codeVerifier: codeVerifier,
            redirectURI: redirectURI,
            authorizationURL: authorizationURL,
            redirectScheme: redirectScheme
        )
    }

    private func googleReversedClientIdScheme() throws -> String {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") else {
            throw FirebaseAuthRepositoryError.missingClientId
        }

        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dict = plist as? [String: Any],
            let scheme = dict["REVERSED_CLIENT_ID"] as? String,
            !scheme.isEmpty
        else {
            throw FirebaseAuthRepositoryError.missingClientId
        }

        return scheme
    }

    private func exchangeAuthorizationCode(
        _ code: String,
        clientId: String,
        codeVerifier: String,
        redirectURI: URL
    ) async throws -> GoogleTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let formBody: [String: String] = [
            "code": code,
            "client_id": clientId,
            "code_verifier": codeVerifier,
            "redirect_uri": redirectURI.absoluteString,
            "grant_type": "authorization_code"
        ]

        request.httpBody = formBody
            .map { key, value in "\(Self.formEncode(key))=\(Self.formEncode(value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FirebaseAuthRepositoryError.tokenExchangeFailed("Invalid response.")
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw FirebaseAuthRepositoryError.tokenExchangeFailed(body)
        }

        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    private func signInToFirebase(idToken: String, accessToken: String) async throws -> AuthSession {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await Auth.auth().signIn(with: credential)

        return AuthSession(
            user: AuthUser(
                uid: authResult.user.uid,
                email: authResult.user.email,
                displayName: authResult.user.displayName,
                photoURL: authResult.user.photoURL?.absoluteString
            )
        )
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func formEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
