import Foundation

@MainActor
final class AppFeatures {
    private let features: [FeatureRuntime]

    init(context: FeatureContext) {
        self.features = [
            SettingsFeature(context: context),
            ChatsFeature(context: context),
            ClientVoiceFeature(context: context),
            MemoriesFeature(context: context),
            SensitiveDataFeature(context: context),
            IssuesFeature(context: context),
            MCPServersFeature(context: context),
            AIConnectionFeature(context: context),
            WhatsAppCrawlingFeature(context: context),
        ]
    }

    var all: [FeatureRuntime] {
        features
    }

    func executeForEachFeature(
        _ operation: @escaping @MainActor (FeatureRuntime) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for feature in features {
                group.addTask {
                    await operation(feature)
                }
            }
        }
    }

    func feature<T: FeatureRuntime>(_ type: T.Type) -> T {
        guard let feature = features.first(where: { $0 is T }) as? T else {
            fatalError("Feature \(T.self) is not registered in AppFeatures.")
        }

        return feature
    }
}
