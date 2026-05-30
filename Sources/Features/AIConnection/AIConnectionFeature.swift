import Foundation

@MainActor
final class AIConnectionFeature: FeatureRuntime {
    override class var id: String { "aiConnection" }

    private static let serviceId = "ai.connection"

    private(set) var settings: AIConnectionSettingsWrapper

    required init(context: FeatureContext) {
        let settings = AIConnectionSettingsWrapper(settings: context.settings.store)
        self.settings = settings
        super.init(context: context)

        context.settings.sectionRegistry.register(
            AIConnectionSettingsSectionProvider(wrapper: settings)
        )

        let service = PlaceholderProfileRuntimeService(
            id: Self.serviceId,
            title: "AI Connection"
        )

        context.services.serviceRegistry.register(service)

        context.status.statusRegistry.register(
            AIConnectionRuntimeStatusProvider(service: service)
        )
    }

    override func onStartServices() async {
        if settings.autoStart, let service = context.services.serviceRegistry.service(id: Self.serviceId) {
            await service.start()
        }
    }

    override func onStopServices() async {
        if let service = context.services.serviceRegistry.service(id: Self.serviceId) {
            await service.stop()
        }
    }
}
