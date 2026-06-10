import Foundation

struct GoogleContact: Codable, Equatable, Sendable, Identifiable {
    let resourceName: String
    let displayName: String
    let givenName: String?
    let familyName: String?
    let emailAddresses: [String]
    let phoneNumbers: [String]
    let organizationName: String?
    let photoUrl: String?

    var id: String { resourceName }
}
