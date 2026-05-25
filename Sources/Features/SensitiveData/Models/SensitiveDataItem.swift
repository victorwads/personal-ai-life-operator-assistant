import Foundation

struct SensitiveDataItem: Codable, Equatable, Sendable {
    let key: String
    let kind: SensitiveDataKind
    let value: String?
    let issueId: String?
    let deletedAt: Date?
}
