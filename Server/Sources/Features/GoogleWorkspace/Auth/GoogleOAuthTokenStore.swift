import Foundation

@MainActor
final class GoogleOAuthTokenStore {
    private let settingsStore: SettingsStore
    private static let scope = "googleWorkspaceAuth"
    private static let tokenKey = "token"

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func loadToken() -> GoogleOAuthToken? {
        guard let tokenString = settingsStore.value(scope: Self.scope, key: Self.tokenKey),
              let data = Data(base64Encoded: tokenString) else {
            return nil
        }
        return try? JSONDecoder().decode(GoogleOAuthToken.self, from: data)
    }

    func saveToken(_ token: GoogleOAuthToken) {
        var tokenToSave = token
        // Google OAuth refresh tokens are only returned on the first authorization flow.
        // During a refresh token exchange, Google only returns a new access token.
        // Therefore, we must preserve the existing refresh token if the new one is nil.
        if token.refreshToken == nil, let existingToken = loadToken() {
            tokenToSave = GoogleOAuthToken(
                accessToken: token.accessToken,
                refreshToken: existingToken.refreshToken,
                expiresAt: token.expiresAt,
                scope: token.scope,
                tokenType: token.tokenType
            )
        }
        
        guard let data = try? JSONEncoder().encode(tokenToSave) else {
            return
        }
        let tokenString = data.base64EncodedString()
        settingsStore.setValue(scope: Self.scope, key: Self.tokenKey, value: tokenString)
    }

    func clearToken() {
        settingsStore.deleteValue(scope: Self.scope, key: Self.tokenKey)
    }
}
