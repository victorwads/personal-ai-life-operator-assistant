import Foundation

struct MCPToolExampleParameter: Codable, Equatable, Sendable {
    let name: String
    let value: MCPJSONValue
    let note: String?
}
