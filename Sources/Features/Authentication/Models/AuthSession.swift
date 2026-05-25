import Foundation

struct AuthSession: Codable, Equatable, Sendable {
    let user: AuthUser
    let isAuthenticated: Bool

    init(user: AuthUser, isAuthenticated: Bool = true) {
        self.user = user
        self.isAuthenticated = isAuthenticated
    }
}
