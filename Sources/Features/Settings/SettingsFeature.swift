import Foundation

@MainActor
final class SettingsFeature: FeatureRuntime {
    override class var id: String { "settings" }

    var settingsSectionRegistry: SettingsSectionRegistry {
        context.settings.sectionRegistry
    }
}
