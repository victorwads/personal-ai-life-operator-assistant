import Foundation

@MainActor
final class SensitiveDataFeature: FeatureRuntime {
    override class var id: String { "sensitiveData" }
    let repositories: SensitiveDataRepositories

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("SensitiveDataFeature requires a persisted profile scope.")
        }

        let repositories = SensitiveDataRepositories(
            data: FirestoreSensitiveDataRepository(scope: scope),
            usage: FirestoreSensitiveDataUsageRepository(scope: scope)
        )
        self.repositories = repositories
        super.init(context: context)
        context.mcp.toolRegistry.register([
            SaveSensitiveDataTool(repositories: repositories),
            GetSensitiveDataTool(repositories: repositories),
            ListSensitiveDataTool(repositories: repositories),
            SearchSensitiveDataTool(repositories: repositories),
            UpdateSensitiveDataTool(repositories: repositories),
            DeleteSensitiveDataTool(repositories: repositories)
        ])
    }
}
