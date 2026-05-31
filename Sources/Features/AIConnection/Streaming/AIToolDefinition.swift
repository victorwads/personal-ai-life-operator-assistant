import Foundation

struct AIToolDefinition: Equatable, Sendable {
    let name: String
    let description: String
    let inputSchema: AIJSONValue
}
