import Foundation

public protocol PersistableModel: Codable, Identifiable {
    var id: String { get set }
    var createdAt: Date { get set }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}
