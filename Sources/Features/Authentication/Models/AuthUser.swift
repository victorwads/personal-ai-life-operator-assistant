import Foundation

struct AuthUser: Codable, Equatable, Sendable, Identifiable {
    let uid: String
    let email: String?
    let displayName: String?
    let photoURL: String?

    init(uid: String, email: String?, displayName: String?, photoURL: String?) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
    }

    var id: String {
        uid
    }
}
