import Foundation

struct MCPToolExecutionResult: Codable, Equatable, Sendable {
    let toolName: String
    let success: Bool
    let payload: MCPJSONValue?
    let error: MCPServerError?
    let durationMilliseconds: Double?

    static func success(
        toolName: String,
        payload: MCPJSONValue? = nil,
        durationMilliseconds: Double? = nil
    ) -> MCPToolExecutionResult {
        MCPToolExecutionResult(
            toolName: toolName,
            success: true,
            payload: payload,
            error: nil,
            durationMilliseconds: durationMilliseconds
        )
    }

    static func failure(
        toolName: String,
        error: MCPServerError,
        durationMilliseconds: Double? = nil
    ) -> MCPToolExecutionResult {
        MCPToolExecutionResult(
            toolName: toolName,
            success: false,
            payload: nil,
            error: error,
            durationMilliseconds: durationMilliseconds
        )
    }
}
