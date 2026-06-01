import Foundation

struct AIToolDefinition: Equatable, Sendable {
    let name: String
    let description: String
    let icon: String?
    let inputSchema: AIJSONValue
}
