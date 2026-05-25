import Foundation

protocol SensitiveDataRepository {
    func fetchItem(key: String) async throws -> SensitiveDataItem?
    func listItems() async throws -> [SensitiveDataItem]
    func saveItem(_ item: SensitiveDataItem) async throws
    func deleteItem(key: String) async throws
    func listUsage(for key: String) async throws -> [SensitiveDataUsage]
}
