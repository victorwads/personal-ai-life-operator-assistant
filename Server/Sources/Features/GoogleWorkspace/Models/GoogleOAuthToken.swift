import Foundation

struct GoogleOAuthToken: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scope: String
    let tokenType: String

    var isExpired: Bool {
        // Expired if current time is within 60 seconds of expiresAt or after.
        Date().addingTimeInterval(60) >= expiresAt
    }
}
