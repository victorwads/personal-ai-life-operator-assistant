import Foundation

struct MCPToolExampleParameter: Codable, Equatable, Sendable {
    let name: String
    let value: MCPJSONValue
    let note: String?

    init(name: String, value: MCPJSONValue, note: String? = nil) {
        self.name = name
        self.value = value
        self.note = note
    }

    var jsonValue: MCPJSONValue {
        .object([
            "name": .string(name),
            "value": value,
            "note": note.map(MCPJSONValue.string) ?? .null
        ])
    }
}
