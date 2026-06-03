import Foundation

struct SensitiveDataItem: PersistableModel, Equatable, Sendable {
    @DocumentID var id: String?
    var key: String
    var kind: SensitiveDataKind
    var value: String?
    var issueId: String?
}
