import Foundation

struct MCPToolDefinition: Codable, Equatable, Sendable {
    let name: String
    let title: String?
    let summary: String
    let group: MCPToolGroup
    let traits: [MCPToolTrait]
    let inputSchema: MCPJSONValue?
    let exampleParameters: [MCPToolExampleParameter]

    init(
        name: String,
        title: String? = nil,
        summary: String,
        group: MCPToolGroup,
        traits: [MCPToolTrait],
        inputSchema: MCPJSONValue? = nil,
        exampleParameters: [MCPToolExampleParameter] = []
    ) {
        self.name = name
        self.title = title
        self.summary = summary
        self.group = group
        self.traits = traits
        self.inputSchema = inputSchema
        self.exampleParameters = exampleParameters
    }
}
