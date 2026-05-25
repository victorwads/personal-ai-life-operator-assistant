import Foundation

final class MCPToolRegistry {
    private var providers: [any MCPToolProvider]
    private var handlersByName: [String: any MCPToolHandler.Type]

    init(providers: [any MCPToolProvider] = []) {
        self.providers = []
        self.handlersByName = [:]
        register(providers: providers)
    }

    func register(provider: any MCPToolProvider) {
        providers.append(provider)
        for handlerType in provider.tools {
            handlersByName[handlerType.definition.name] = handlerType
        }
    }

    func register(providers: [any MCPToolProvider]) {
        for provider in providers {
            register(provider: provider)
        }
    }

    func handlerType(named name: String) -> (any MCPToolHandler.Type)? {
        handlersByName[name]
    }

    func definition(named name: String) -> MCPToolDefinition? {
        handlersByName[name]?.definition
    }

    func allDefinitions() -> [MCPToolDefinition] {
        handlersByName.values.map(\.definition).sorted { $0.name < $1.name }
    }

    func definitions(in group: MCPToolGroup) -> [MCPToolDefinition] {
        allDefinitions().filter { $0.group == group }
    }

    func groupedDefinitions() -> [(group: MCPToolGroup, definitions: [MCPToolDefinition])] {
        MCPToolGroup.allCases.map { group in
            (group: group, definitions: definitions(in: group))
        }
    }
}
