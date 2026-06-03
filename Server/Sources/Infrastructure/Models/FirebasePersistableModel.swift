import Foundation

public protocol FirebasePersistableModel: Codable, Identifiable {
    var id: String? { get set }
}
