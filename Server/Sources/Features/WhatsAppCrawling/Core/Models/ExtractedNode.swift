import Foundation

struct ExtractedNode: Codable, Equatable, Sendable {
    let name: String
    let rawText: String?
    let rawNumber: Double?
    let attributes: [String: String]
    let children: [ExtractedNode]
}
