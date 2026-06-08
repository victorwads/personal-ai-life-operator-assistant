import Foundation

@MainActor
final class AIConnectionFeature: FeatureRuntime {
    override class var id: String { "aiConnection" }

    private static let serviceId = "ai.connection"

    private(set) var errorLogStore: AIConnectionErrorLogStore
    private(set) var settings: AIConnectionSettingsWrapper
    private(set) var streamingService: AIConnectionStreamingService
    private(set) var imageExtractionService: AIImageExtractionService
    private(set) var runtimeService: AIConnectionRuntimeService
    private(set) var resourceUsageRepository: FirestoreAIResourceUsageRepository
    private(set) var runtimeLogger: AIConnectionRuntimeLogger
    private let serverLogsProvider: @MainActor () -> ServerLogsService

    required init(context: FeatureContext) {
        let errorLogStore = AIConnectionErrorLogStore()
        self.errorLogStore = errorLogStore
        let settings = AIConnectionSettingsWrapper(settings: context.settings.store)
        self.settings = settings
        let assistantNameSettings = SentMessagesSettingsWrapper(settings: context.settings.store)
        self.serverLogsProvider = {
            context.feature(ServerLogsFeature.self).service
        }
        let resourceUsageRepository = FirestoreAIResourceUsageRepository(
            profileId: context.profileContext.profileId
        )
        self.resourceUsageRepository = resourceUsageRepository
        let runtimeLogger = AIConnectionRuntimeLogger(
            errorLogStore: errorLogStore,
            serverLogsProvider: serverLogsProvider
        )
        self.runtimeLogger = runtimeLogger
        let memoryBootstrapBridge = AIConnectionMemoryBootstrapBridge(
            featureProvider: {
                context.feature(MemoriesFeature.self)
            }
        )
        let pendingWorkProviders = PendingWorkProviderCatalog.makeProviders(context: context)
        let pendingWorkBootstrapBridge = AIConnectionPendingWorkBootstrapBridge(
            snapshotProvider: {
                try await PendingWorkSnapshotLoader(providers: pendingWorkProviders).load()
            }
        )

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
        let imageExtractionCacheRepository = FirestoreAIImageExtractionCacheRepository(
            profileId: context.profileContext.profileId
        )
        let imageExtractionService = AIImageExtractionService(
            profileId: context.profileContext.profileId,
            streamingService: streamingService,
            settingsProvider: {
                await MainActor.run {
                    settings.imageExtractionProviderConfiguration
                }
            },
            promptProvider: {
                try AIConnectionPromptLoader.loadBundledPrompt(named: "ImageExtraction")
            },
            cacheRepository: imageExtractionCacheRepository,
            resourceUsageRepository: resourceUsageRepository,
            runtimeLogger: runtimeLogger
        )
        self.imageExtractionService = imageExtractionService
        self.runtimeService = AIConnectionRuntimeService(
            streamingService: streamingService,
            memoryBootstrapProvider: {
                await memoryBootstrapBridge.bootstrapMessage()
            },
            pendingWorkBootstrapProvider: {
                await pendingWorkBootstrapBridge.bootstrapMessage()
            },
            systemPromptProvider: {
                AIConnectionRuntimeDefaults.systemPrompt(
                    assistantName: assistantNameSettings.assistantName
                )
            },
            providerConfigurationProvider: {
                settings.assistantProviderConfiguration
            },
            runtimeLogger: runtimeLogger,
            errorLogStore: errorLogStore,
            resourceUsageRepository: resourceUsageRepository,
            serverLogsProvider: serverLogsProvider
        )

        super.init(context: context)

        runtimeService.refreshSystemPrompt()

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
