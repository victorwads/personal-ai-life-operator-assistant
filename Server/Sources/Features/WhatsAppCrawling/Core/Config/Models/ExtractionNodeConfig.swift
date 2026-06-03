import Foundation

struct ExtractionNodeConfig: Decodable, Equatable, Sendable {
    let type: String
    let selector: String?
    let attribute: String?
    let path: String?
    let role: String?
    let roleAny: [String]?
    let subrole: String?
    let descriptionContains: String?
    let descriptionContainsAny: [String]?
    let textContainsAny: [String]?
    let helpContains: String?
    let minHeight: Double?
    let scope: String?
    let extract: [String: ExtractionNodeConfig]?
    let parse: String?
    let from: String?
    let valueFrom: [String]?
    let fallbackNumber: Double?

    enum CodingKeys: String, CodingKey {
        case type
        case selector
        case attribute
        case path
        case role
        case roleAny = "role_any"
        case subrole
        case descriptionContains = "description_contains"
        case descriptionContainsAny = "description_contains_any"
        case textContainsAny = "text_contains_any"
        case helpContains = "help_contains"
        case minHeight = "min_height"
        case scope
        case extract
        case parse
        case from
        case valueFrom = "value_from"
        case fallbackNumber = "fallback_number"
    }
}
