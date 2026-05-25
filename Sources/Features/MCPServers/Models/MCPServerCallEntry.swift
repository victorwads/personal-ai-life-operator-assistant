import Foundation

struct MCPServerCallEntry: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let createdAt: Date
    let method: String?
    let path: String?
    let requestHeaders: [String: String]
    let requestBody: MCPJSONValue?
    let responseStatusCode: Int?
    let responseHeaders: [String: String]
    let responseBody: MCPJSONValue?
    let durationMilliseconds: Double?
    let mcpMethod: String?
    let toolName: String?
}
