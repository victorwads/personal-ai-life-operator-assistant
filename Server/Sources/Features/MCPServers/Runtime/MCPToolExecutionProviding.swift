import Foundation

protocol MCPToolExecutionProviding {
    func execute(_ call: MCPToolCall) async -> MCPToolExecutionResult
}
