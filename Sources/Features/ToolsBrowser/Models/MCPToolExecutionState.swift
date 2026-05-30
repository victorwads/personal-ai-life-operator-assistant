import Foundation

enum MCPToolExecutionState: Equatable {
    case idle
    case running
    case success(MCPToolExecutionResult)
    case failure(MCPToolExecutionResult)
}
