import Foundation

struct GoogleAttachmentMetadata: Codable, Equatable, Sendable, Identifiable {
    var id: String { attachmentId }
    let attachmentId: String
    let filename: String
    let mimeType: String
    let size: Int
}
