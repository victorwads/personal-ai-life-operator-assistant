import Foundation

@MainActor
final class FeatureResolverBox {
    var appFeatures: AppFeatures?

    init(appFeatures: AppFeatures? = nil) {
        self.appFeatures = appFeatures
    }

    func feature<T: FeatureRuntime>(_ type: T.Type) -> T {
        guard let appFeatures else {
            fatalError("Feature resolver is not configured yet. This usually means a feature tried to resolve another feature during initialization.")
        }

        return appFeatures.feature(type)
    }
}

