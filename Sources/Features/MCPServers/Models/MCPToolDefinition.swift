import Foundation

struct MCPToolDefinition: Codable, Equatable, Sendable {
    let name: String
    let icon: String
    let description: String
    let group: MCPToolGroup
    let inputSchema: MCPJSONValue
    let exampleParameters: [MCPToolExampleParameter]
    let traits: [MCPToolTrait]

    init(
        name: String,
        icon: String,
        description: String,
        group: MCPToolGroup,
        inputSchema: MCPJSONValue,
        exampleParameters: [MCPToolExampleParameter] = [],
        traits: [MCPToolTrait]
    ) {
        self.name = name
        self.icon = icon
        self.description = description
        self.group = group
        self.inputSchema = inputSchema
        self.exampleParameters = exampleParameters
        self.traits = traits
    }

    var jsonValue: MCPJSONValue {
        .object([
            "name": .string(name),
            "icon": .string(icon),
            "description": .string(description),
            "inputSchema": inputSchema,
            "exampleParameters": .array(exampleParameters.map(\.jsonValue)),
            "traits": .array(traits.map { .string($0.rawValue) })
        ])
    }
}
