import Foundation

enum SensitiveDataKind: String, Codable, CaseIterable, Sendable {
    case document
    case email
    case personalInfo
    case bankInformation
    case healthInformation
    case relationshipInfo
    case other
}
