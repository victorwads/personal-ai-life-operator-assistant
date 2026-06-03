import Foundation

@MainActor
final class AIConnectionFeature: FeatureRuntime {
    override class var id: String { "aiConnection" }

    private static let serviceId = "ai.connection"

    private(set) var errorLogStore: AIConnectionErrorLogStore
    private(set) var settings: AIConnectionSettingsWrapper
    private(set) var streamingService: AIConnectionStreamingService
    private(set) var runtimeService: AIConnectionRuntimeService
    private let serverLogsProvider: @MainActor () -> ServerLogsService

    required init(context: FeatureContext) {
        let errorLogStore = AIConnectionErrorLogStore()
        self.errorLogStore = errorLogStore
        let settings = AIConnectionSettingsWrapper(settings: context.settings.store)
        self.settings = settings
        self.serverLogsProvider = {
            context.feature(ServerLogsFeature.self).service
        }

        let streamingService = AIConnectionStreamingService(
            settingsProvider: {
                await MainActor.run {
                    settings.providerConfiguration
                }
            },
            toolCatalog: MCPToolCatalogBridge(
                featureProvider: {
                    context.feature(MCPServersFeature.self)
                }
            ),
            toolExecutor: MCPToolExecutorBridge(
                featureProvider: {
                    context.feature(MCPServersFeature.self)
                }
            ),
            providerExchangeLogger: { payload in
                do {
                    _ = try errorLogStore.writeProviderExchangeLog(payload)
                } catch {
                    print("AIConnection provider exchange log failed: \(error.localizedDescription)")
                }
            }
        )
        self.streamingService = streamingService
        self.runtimeService = AIConnectionRuntimeService(
            streamingService: streamingService,
            errorLogStore: errorLogStore,
            serverLogsProvider: serverLogsProvider
        )

        super.init(context: context)

        context.settings.sectionRegistry.register(
            AIConnectionSettingsSectionProvider(wrapper: settings)
        )

        let service = AIConnectionProfileRuntimeService(
            id: Self.serviceId,
            title: "AI Connection",
            runtimeService: runtimeService
        )

        context.services.serviceRegistry.register(service)

        context.status.statusRegistry.register(
            AIConnectionRuntimeStatusProvider(runtimeService: runtimeService)
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
