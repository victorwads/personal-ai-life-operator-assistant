import Foundation
import AppKit

@MainActor
final class GoogleOAuthService {
    private let settings: GoogleWorkspaceSettingsWrapper
    private let tokenStore: GoogleOAuthTokenStore

    private(set) var currentConnectingState: String?
    private var activeRedirectServer: GoogleOAuthLocalRedirectServer?
    
    // Track active refresh task to deduplicate simultaneous refreshes
    private var activeRefreshTask: Task<String, Error>?

    init(settings: GoogleWorkspaceSettingsWrapper, tokenStore: GoogleOAuthTokenStore) {
        self.settings = settings
        self.tokenStore = tokenStore
    }

    var state: GoogleWorkspaceAuthState {
        if let connectingState = currentConnectingState {
            return .connecting(state: connectingState)
        }
        guard let token = tokenStore.loadToken() else {
            return .disconnected
        }
        return .connected(
            scopes: token.scope.components(separatedBy: " "),
            expiresAt: token.expiresAt
        )
    }

    func startOAuthFlow(forceConsent: Bool = false) async throws {
        let clientId = settings.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = settings.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let redirectPort = settings.redirectPort

        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            throw NSError(domain: "GoogleOAuthService", code: 101, userInfo: [
                NSLocalizedDescriptionKey: "Missing Google Client ID or Client Secret. Configure them in Settings."
            ])
        }

        let stateString = UUID().uuidString.lowercased()
        currentConnectingState = stateString

        let redirectUri = "http://127.0.0.1:\(redirectPort)/oauth/google/callback"
        
        let scopes = settings.enabledScopes.joined(separator: " ")
        var authComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        authComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: stateString),
            URLQueryItem(name: "access_type", value: "offline")
        ]
        
        if forceConsent {
            authComponents.queryItems?.append(URLQueryItem(name: "prompt", value: "consent"))
        }

        guard let authUrl = authComponents.url else {
            currentConnectingState = nil
            throw NSError(domain: "GoogleOAuthService", code: 102, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate authorization URL."
            ])
        }

        let redirectServer = GoogleOAuthLocalRedirectServer()
        activeRedirectServer = redirectServer

        // Open user browser
        NSWorkspace.shared.open(authUrl)

        do {
            let authCode = try await redirectServer.startAndAwaitCode(port: redirectPort, expectedState: stateString)
            let token = try await exchangeCodeForToken(code: authCode, redirectUri: redirectUri)
            tokenStore.saveToken(token)
            currentConnectingState = nil
            activeRedirectServer = nil
        } catch {
            currentConnectingState = nil
            activeRedirectServer = nil
            throw error
        }
    }

    func disconnect() {
        tokenStore.clearToken()
        currentConnectingState = nil
    }

    func ensureValidToken() async throws -> String {
        if let activeRefreshTask = activeRefreshTask {
            return try await activeRefreshTask.value
        }

        guard let token = tokenStore.loadToken() else {
            throw NSError(domain: "GoogleOAuthService", code: 103, userInfo: [
                NSLocalizedDescriptionKey: "Google Workspace is not connected. Please authenticate."
            ])
        }

        if !token.isExpired {
            return token.accessToken
        }

        let task = Task { () -> String in
            defer { self.activeRefreshTask = nil }
            let refreshedToken = try await self.performRefreshTokenExchange(refreshToken: token.refreshToken)
            self.tokenStore.saveToken(refreshedToken)
            return refreshedToken.accessToken
        }
        self.activeRefreshTask = task
        return try await task.value
    }

    func forceRefresh() async throws -> String {
        guard let token = tokenStore.loadToken() else {
            throw NSError(domain: "GoogleOAuthService", code: 104, userInfo: [
                NSLocalizedDescriptionKey: "Google Workspace is not connected."
            ])
        }

        let refreshedToken = try await performRefreshTokenExchange(refreshToken: token.refreshToken)
        tokenStore.saveToken(refreshedToken)
        return refreshedToken.accessToken
    }

    private func exchangeCodeForToken(code: String, redirectUri: String) async throws -> GoogleOAuthToken {
        let clientId = settings.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = settings.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters = [
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = buildQueryString(from: parameters).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GoogleOAuthService", code: 105, userInfo: [
                NSLocalizedDescriptionKey: "Invalid server response."
            ])
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "GoogleOAuthService", code: 106, userInfo: [
                NSLocalizedDescriptionKey: "Token exchange failed: \(errorText)"
            ])
        }

        let responseJSON = try JSONDecoder().decode(GoogleOAuthTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(Double(responseJSON.expires_in))

        return GoogleOAuthToken(
            accessToken: responseJSON.access_token,
            refreshToken: responseJSON.refresh_token,
            expiresAt: expiresAt,
            scope: responseJSON.scope ?? settings.enabledScopes.joined(separator: " "),
            tokenType: responseJSON.token_type
        )
    }

    private func performRefreshTokenExchange(refreshToken: String?) async throws -> GoogleOAuthToken {
        guard let refreshToken = refreshToken, !refreshToken.isEmpty else {
            throw NSError(domain: "GoogleOAuthService", code: 107, userInfo: [
                NSLocalizedDescriptionKey: "Missing refresh token. Please re-authenticate."
            ])
        }

        let clientId = settings.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = settings.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = buildQueryString(from: parameters).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GoogleOAuthService", code: 108, userInfo: [
                NSLocalizedDescriptionKey: "Invalid server response during refresh."
            ])
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "GoogleOAuthService", code: 109, userInfo: [
                NSLocalizedDescriptionKey: "Token refresh failed: \(errorText)"
            ])
        }

        let responseJSON = try JSONDecoder().decode(GoogleOAuthTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(Double(responseJSON.expires_in))

        return GoogleOAuthToken(
            accessToken: responseJSON.access_token,
            // Keep existing refresh token if not returned (common in refresh flows)
            refreshToken: responseJSON.refresh_token ?? refreshToken,
            expiresAt: expiresAt,
            scope: responseJSON.scope ?? settings.enabledScopes.joined(separator: " "),
            tokenType: responseJSON.token_type
        )
    }

    private func buildQueryString(from parameters: [String: String]) -> String {
        parameters.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
}

// Temporary decodable model for parsing Google's token endpoint response
private struct GoogleOAuthTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let token_type: String
    let refresh_token: String?
    let scope: String?
}
