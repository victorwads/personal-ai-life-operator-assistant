import Foundation

protocol MCPServerCallStore {
    func append(_ entry: MCPServerCallEntry) async
    func list() async -> [MCPServerCallEntry]
    func clear() async
}
