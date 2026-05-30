import Foundation

@MainActor
final class ClientVoiceFeature: FeatureRuntime {
    override class var id: String { "clientVoice" }

    required init(context: FeatureContext) {
        super.init(context: context)
        context.mcp.toolRegistry.register(provider: ClientVoiceMCPToolProvider())
    }
}
