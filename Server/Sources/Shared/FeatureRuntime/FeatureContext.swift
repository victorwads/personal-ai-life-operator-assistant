import Foundation

@MainActor
struct FeatureContext {
    let profileContext: ProfileContext
    let settings: SettingsContext
    let mcp: MCPContext
    let services: FeatureServicesContext
    let status: FeatureStatusContext
    let featureWindows: FeatureWindowsContext
    let sharedLocks: SharedLockRegistry
    let featureResolver: FeatureResolverBox

    func feature<T: FeatureRuntime>(_ type: T.Type) -> T {
        featureResolver.feature(type)
    }
}
