import Foundation

@MainActor
final class MemoriesFeature: FeatureRuntime {
    override class var id: String { "memories" }

    private(set) var repository: FirestoreMemoryRepository

    required init(context: FeatureContext) {
        guard let scope = context.profileContext.scope else {
            preconditionFailure("MemoriesFeature requires a persisted profile scope.")
        }

        let repository = FirestoreMemoryRepository(scope: scope)
        self.repository = repository
        super.init(context: context)

        context.mcp.toolRegistry.register(
            provider: MemoriesMCPToolProvider(repository: repository)
        )
    }
}
