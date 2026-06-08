import Foundation

@MainActor
final class WhatsAppCrawlingFeature: FeatureRuntime {
    override class var id: String { "whatsAppCrawling" }

    private static let webViewServiceId = "whatsapp.webview"
    private static let crawlingServiceId = "whatsapp.crawling"

    private(set) var crawlingSettings: WhatsAppCrawlingSettingsWrapper
    private(set) var webViewSettings: WhatsAppWebViewSettingsWrapper
    private(set) var nativeSettings: WhatsAppNativeSettingsWrapper
    private(set) var logStore: WhatsAppCrawlingLogStore
    private(set) var webViewService: WebViewWhatsAppCrawlingService
    private(set) var pollingService: WhatsAppCrawlingPollingService?
    private(set) var messageSender: any WhatsAppMessageSending

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("WhatsAppCrawlingFeature requires a persisted profile scope.")
        }

        let crawlingSettings = WhatsAppCrawlingSettingsWrapper(settings: context.settings.store)
        let webViewSettings = WhatsAppWebViewSettingsWrapper(settings: context.settings.store)
        let nativeSettings = WhatsAppNativeSettingsWrapper(settings: context.settings.store)
        let clientVoiceSettings = ClientVoiceSettingsWrapper(settings: context.settings.store)
        let audioTranscriptionCacheRepository = FirestoreWhatsAppAudioTranscriptionCacheRepository(
            profileId: context.profileContext.profileId
        )
        let logStore = WhatsAppCrawlingLogStore()
        let webViewService = WebViewWhatsAppCrawlingService(
            profileId: context.profileContext.profileId,
            settings: webViewSettings
        )

        self.crawlingSettings = crawlingSettings
        self.webViewSettings = webViewSettings
        self.nativeSettings = nativeSettings
        self.logStore = logStore
        self.webViewService = webViewService
        self.pollingService = nil
        self.messageSender = WebViewMessageSender(
            webViewService: webViewService,
            pollingService: nil,
            logStore: logStore
        )
        super.init(context: context)

        context.settings.sectionRegistry.register(
            WhatsAppCrawlingSettingsSectionProvider(
                crawlingSettings: crawlingSettings,
                webViewSettings: webViewSettings,
                nativeSettings: nativeSettings
            )
        )

        context.services.serviceRegistry.register(
            WhatsAppCrawlingProfileRuntimeService(
                id: Self.webViewServiceId,
                title: "WhatsApp WebView",
                service: webViewService
            )
        )

        do {
            let crawlingService = try WhatsAppCrawlingPollingService(
                profileId: context.profileContext.profileId,
                settings: crawlingSettings,
                webViewService: webViewService,
                chatRepositoryProvider: { context.feature(ChatsFeature.self).repository },
                aiImageExtractorProvider: {
                    context.feature(AIConnectionFeature.self).imageExtractionService
                },
                audioTranscriptionServiceProvider: {
                    WhatsAppAudioTranscriptionService(
                        profileId: context.profileContext.profileId,
                        settingsProvider: { clientVoiceSettings },
                        cacheRepository: audioTranscriptionCacheRepository
                    )
                },
                logStore: logStore,
                sharedLocks: context.sharedLocks
            )
            self.pollingService = crawlingService
            self.messageSender = WebViewMessageSender(
                webViewService: webViewService,
                pollingService: crawlingService,
                logStore: logStore
            )

            context.services.serviceRegistry.register(
                WhatsAppCrawlingProfileRuntimeService(
                    id: Self.crawlingServiceId,
                    title: "WhatsApp Crawling/Polling",
                    service: crawlingService
                )
            )

            if
                let registeredWebViewService = context.services.serviceRegistry.service(id: Self.webViewServiceId),
                let registeredCrawlingService = context.services.serviceRegistry.service(id: Self.crawlingServiceId)
            {
                context.status.statusRegistry.register(
                    WhatsAppRuntimeStatusProvider(
                        webViewService: registeredWebViewService,
                        crawlingService: registeredCrawlingService
                    )
                )
            }
        } catch {
            logStore.append(source: "WhatsAppCrawlingFeature", "Failed to create crawling service: \(error.localizedDescription)")
        }
    }

    override func onStartServices() async {
        if let service = context.services.serviceRegistry.service(id: Self.webViewServiceId),
           webViewSettings.autoStart {
            await service.start()
        }

        if let service = context.services.serviceRegistry.service(id: Self.crawlingServiceId),
           crawlingSettings.autoStart {
            await service.start()
        }
    }

    override func onStopServices() async {
        if let service = context.services.serviceRegistry.service(id: Self.crawlingServiceId) {
            await service.stop()
        }

        if let service = context.services.serviceRegistry.service(id: Self.webViewServiceId) {
            await service.stop()
        }
    }
}
