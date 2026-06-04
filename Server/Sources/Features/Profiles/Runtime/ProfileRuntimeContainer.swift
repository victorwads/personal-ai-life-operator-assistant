import Foundation

/// Profile-scoped runtime container for one profile.
///
/// The container can exist for UI/settings while profile services are stopped.
/// Starting services is an explicit lifecycle step.
@MainActor
final class ProfileRuntimeContainer {
    let context: ProfileContext
    let settings: SettingsStore
    let settingsSectionRegistry: SettingsSectionRegistry
    let mcpToolRegistry: MCPToolRegistry
    let serviceRegistry: ProfileRuntimeServiceRegistry
    let statusRegistry: ProfileRuntimeStatusRegistry

    let appFeatures: AppFeatures

    init(context: ProfileContext, windowManager: ProfileWindowManaging?) throws {
        guard let scope = context.scope else {
            throw ProfileRuntimeContainerError.missingProfileScope
        }

        self.context = context
        self.settings = SettingsStore(scope: scope)
        self.settingsSectionRegistry = SettingsSectionRegistry()

        self.mcpToolRegistry = MCPToolRegistry()
        self.serviceRegistry = ProfileRuntimeServiceRegistry()
        self.statusRegistry = ProfileRuntimeStatusRegistry()

        let featureResolver = FeatureResolverBox()
        let sharedLocks = SharedLockRegistry()
        let featureContext = FeatureContext(
            profileContext: context,
            settings: SettingsContext(store: settings, sectionRegistry: settingsSectionRegistry),
            mcp: MCPContext(toolRegistry: mcpToolRegistry),
            services: FeatureServicesContext(serviceRegistry: serviceRegistry),
            status: FeatureStatusContext(statusRegistry: statusRegistry),
            featureWindows: FeatureWindowsContext(
                show: { request in
                    windowManager?.showFeatureWindow(profileId: context.profileId, request: request)
                },
                hide: { featureWindowId in
                    windowManager?.hideFeatureWindow(profileId: context.profileId, featureWindowId: featureWindowId)
                }
            ),
            sharedLocks: sharedLocks,
            featureResolver: featureResolver
        )
        self.appFeatures = AppFeatures(context: featureContext)
        featureResolver.appFeatures = appFeatures
    }

    func startSettings() async throws {
        try await settings.start()
        await appFeatures.executeForEachFeature { feature in await feature.startObserving()}
    }

    func startServices() async throws {
        try await startSettings()
        await appFeatures.executeForEachFeature { feature in await feature.startServices() }
    }

    func stopServices() async {
        await appFeatures.executeForEachFeature { feature in await feature.stopServices()}
    }

    func stop(flushPendingSettings: Bool = true) async {
        await stopServices()
        await appFeatures.executeForEachFeature { feature in await feature.stopObserving() }
        await settings.stop(flushPendingSaves: flushPendingSettings)
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
