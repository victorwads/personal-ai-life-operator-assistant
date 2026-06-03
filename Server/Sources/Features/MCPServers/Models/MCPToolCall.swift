import Foundation

struct MCPToolCall: Codable, Equatable, Sendable {
    let name: String
    let arguments: [String: MCPJSONValue]

    init(name: String, arguments: [String: MCPJSONValue] = [:]) {
        self.name = name
        self.arguments = arguments
    }
}
