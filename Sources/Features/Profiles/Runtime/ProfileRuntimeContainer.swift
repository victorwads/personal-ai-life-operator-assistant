import Foundation

/// Profile-scoped service bubble for one running profile.
///
/// TODO: Render CommandCenter from this running profile container so feature
/// screens can receive profile-owned services without owning their lifecycles.
@MainActor
final class ProfileRuntimeContainer {
    let context: ProfileContext
    let settings: SettingsStore
    let settingsSectionRegistry: SettingsSectionRegistry
    let aiConnectionSettings: AIConnectionSettingsWrapper
    let whatsAppCrawlingSettings: WhatsAppCrawlingSettingsWrapper
    let whatsAppWebViewSettings: WhatsAppWebViewSettingsWrapper
    let whatsAppNativeSettings: WhatsAppNativeSettingsWrapper

    private(set) var whatsAppCrawlingService: (any WhatsAppCrawlingService)?

    init(context: ProfileContext) throws {
        guard let scope = context.scope else {
            throw ProfileRuntimeContainerError.missingProfileScope
        }

        self.context = context
        self.settings = SettingsStore(scope: scope)
        self.aiConnectionSettings = AIConnectionSettingsWrapper(settings: settings)
        self.whatsAppCrawlingSettings = WhatsAppCrawlingSettingsWrapper(settings: settings)
        self.whatsAppWebViewSettings = WhatsAppWebViewSettingsWrapper(settings: settings)
        self.whatsAppNativeSettings = WhatsAppNativeSettingsWrapper(settings: settings)
        self.settingsSectionRegistry = SettingsSectionRegistry()
        self.settingsSectionRegistry.register(
            WhatsAppCrawlingSettingsSectionProvider(
                crawlingSettings: whatsAppCrawlingSettings,
                webViewSettings: whatsAppWebViewSettings,
                nativeSettings: whatsAppNativeSettings
            )
        )
        self.settingsSectionRegistry.register(
            AIConnectionSettingsSectionProvider(wrapper: aiConnectionSettings)
        )
    }

    func start() async throws {
        try await settings.start()

        let factory = WhatsAppCrawlingServiceFactory(
            crawlingSettings: whatsAppCrawlingSettings,
            webViewSettings: whatsAppWebViewSettings,
            nativeSettings: whatsAppNativeSettings,
            profileId: context.profileId
        )
        let service = try await factory.makeService()
        whatsAppCrawlingService = service
        await service.start()
    }

    func stop() async {
        await whatsAppCrawlingService?.stop()
        whatsAppCrawlingService = nil
        await settings.stop()
    }
}

private enum ProfileRuntimeContainerError: LocalizedError {
    case missingProfileScope

    var errorDescription: String? {
        switch self {
        case .missingProfileScope:
            return "Profile runtime cannot start without a persisted profile id."
        }
    }
}
