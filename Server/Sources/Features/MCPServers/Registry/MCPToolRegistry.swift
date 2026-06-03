import Foundation

final class MCPToolRegistry {
    private var definitionsByName: [String: any MCPToolDefinition]

    init(definitions: [any MCPToolDefinition] = []) {
        self.definitionsByName = [:]
        register(definitions)
    }

    func register(_ definitions: [any MCPToolDefinition]) {
        for definition in definitions {
            definitionsByName[definition.name] = definition
        }
    }

    func definition(named name: String) -> (any MCPToolDefinition)? {
        definitionsByName[name]
    }

    func allDefinitions() -> [any MCPToolDefinition] {
        definitionsByName.values.sorted { $0.name < $1.name }
    }

    func definitions(in group: String) -> [any MCPToolDefinition] {
        allDefinitions().filter { $0.group == group }
    }

    func groupedDefinitions() -> [(group: String, definitions: [any MCPToolDefinition])] {
        Dictionary(grouping: allDefinitions(), by: \.group)
            .map { (group: $0.key, definitions: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.group < $1.group }
    }
}
