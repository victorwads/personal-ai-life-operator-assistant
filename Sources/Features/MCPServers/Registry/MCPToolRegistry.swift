import Foundation

final class MCPToolRegistry {
    private var providers: [any MCPToolProvider]
    private var registrationsByName: [String: MCPToolRegistration]

    init(providers: [any MCPToolProvider] = []) {
        self.providers = []
        self.registrationsByName = [:]
        register(providers: providers)
    }

    func register(provider: any MCPToolProvider) {
        providers.append(provider)
        for handlerType in provider.tools {
            let registration = MCPToolRegistration(
                definition: handlerType.definition,
                makeHandler: { handlerType.init() }
            )
            registrationsByName[registration.definition.name] = registration
        }
    }

    func register(providers: [any MCPToolProvider]) {
        for provider in providers {
            register(provider: provider)
        }
    }

    func registration(named name: String) -> MCPToolRegistration? {
        registrationsByName[name]
    }

    func definition(named name: String) -> MCPToolDefinition? {
        registrationsByName[name]?.definition
    }

    func allDefinitions() -> [MCPToolDefinition] {
        registrationsByName.values.map(\.definition).sorted { $0.name < $1.name }
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

struct MCPToolRegistration {
    let definition: MCPToolDefinition
    let makeHandler: () -> any MCPToolHandler
}
