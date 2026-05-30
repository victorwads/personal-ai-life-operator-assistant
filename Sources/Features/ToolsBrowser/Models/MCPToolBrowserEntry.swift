import Foundation

struct MCPToolBrowserEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let group: String
    let traits: [MCPToolTrait]

    init(tool: any MCPToolDefinition) {
        self.id = tool.name
        self.name = tool.name
        self.icon = tool.icon
        self.description = tool.description
        self.group = tool.group
        self.traits = tool.traits
    }
}
