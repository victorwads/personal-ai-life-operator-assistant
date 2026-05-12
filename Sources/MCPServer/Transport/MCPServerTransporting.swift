import Foundation

protocol MCPServerTransporting: AnyObject {
    var isRunning: Bool { get }
    var boundPort: Int { get }
    func configure(host: String, port: Int)
    func setRequestHandler(_ handler: @escaping @Sendable (MCPHTTPRequest) async -> Result<JSONValue, Error>)
    func setStateHandler(_ handler: @escaping @Sendable (MCPServerState) -> Void)
    func start() async throws
    func stop() async
}
