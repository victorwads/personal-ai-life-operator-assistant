import Foundation

@MainActor
final class SensitiveDataFeature: FeatureRuntime {
    override class var id: String { "sensitiveData" }

    required init(context: FeatureContext) {
        super.init(context: context)
        context.mcp.toolRegistry.register(provider: SensitiveDataMCPToolProvider())
    }
}
