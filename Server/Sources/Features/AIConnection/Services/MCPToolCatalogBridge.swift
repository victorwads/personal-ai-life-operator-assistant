import Foundation

@MainActor
final class MCPToolCatalogBridge: AIConnectionToolCataloging {
    private let featureProvider: @MainActor () -> MCPServersFeature

    init(featureProvider: @escaping @MainActor () -> MCPServersFeature) {
        self.featureProvider = featureProvider
    }

    func listTools() -> [AIToolDefinition] {
        featureProvider().listToolDefinitions().map { definition in
            AIToolDefinition(
                name: definition.name,
                description: definition.description,
                icon: definition.icon,
                inputSchema: Self.aiValue(definition.inputSchema),
                traits: definition.traits
            )
        }
    }

    private static func aiValue(_ value: MCPJSONValue) -> AIJSONValue {
        switch value {
        case .null:
            return .null
        case let .bool(value):
            return .bool(value)
        case let .int(value):
            return .int(value)
        case let .double(value):
            return .double(value)
        case let .string(value):
            return .string(value)
        case let .array(values):
            return .array(values.map(aiValue))
        case let .object(values):
            return .object(values.mapValues(aiValue))
        }
    }
}
