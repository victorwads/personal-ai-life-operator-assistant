import Foundation

@MainActor
final class AIRuntimeFeature: FeatureRuntime {
    override class var id: String { "aiRuntime" }

    static let sharedRuntime = AIRuntime(configuration: .localQwenDefault)

    private(set) var runtime: AIRuntime
    private(set) var settings: AIRuntimeSettingsWrapper

    required init(context: FeatureContext) {
        self.runtime = Self.sharedRuntime
        self.settings = AIRuntimeSettingsWrapper(settings: context.settings.store)
        super.init(context: context)
    }
}
