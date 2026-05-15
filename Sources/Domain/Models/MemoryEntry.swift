import Foundation

struct MemoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date
}

