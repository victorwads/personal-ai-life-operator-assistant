import Foundation

protocol MCPServerCallLogger {
    func log(_ entry: MCPServerCallEntry) async
}
