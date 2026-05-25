import Foundation

enum AuthState: Equatable, Sendable {
    case loading
    case unauthenticated
    case authenticated
    case failed(message: String)
}
