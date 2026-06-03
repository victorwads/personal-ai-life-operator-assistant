import Foundation

struct FlowConfig: Decodable, Equatable, Sendable {
    let type: String
    let textIncludesAny: [String]?
    let requiresAny: [FlowRequirementConfig]?

    enum CodingKeys: String, CodingKey {
        case type
        case textIncludesAny = "text_includes_any"
        case requiresAny = "requires_any"
    }
}

struct FlowRequirementConfig: Decodable, Equatable, Sendable {
    let type: String
    let selector: String?
    let path: String?
    let role: String?
    let roleAny: [String]?
    let subrole: String?
    let descriptionContains: String?
    let descriptionContainsAny: [String]?
    let textContainsAny: [String]?
    let helpContains: String?
    let scope: String?
    let minHeight: Double?
    let match: FlowMatchConfig?

    enum CodingKeys: String, CodingKey {
        case type
        case selector
        case path
        case role
        case roleAny = "role_any"
        case subrole
        case descriptionContains = "description_contains"
        case descriptionContainsAny = "description_contains_any"
        case textContainsAny = "text_contains_any"
        case helpContains = "help_contains"
        case scope
        case minHeight = "min_height"
        case match
    }
}

struct FlowMatchConfig: Decodable, Equatable, Sendable {
    let kind: String?
    let value: YAMLValue?
}
