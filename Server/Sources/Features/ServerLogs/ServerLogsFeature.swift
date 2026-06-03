import Foundation

@MainActor
final class ServerLogsFeature: FeatureRuntime {
    override class var id: String { "serverLogs" }

    private(set) var repository: any ServerLogRepository
    private(set) var service: ServerLogsService

    required init(context: FeatureContext) {
        let repository = SQLiteServerLogRepository(profileId: context.profileContext.profileId)
        self.repository = repository
        self.service = ServerLogsService(repository: repository)
        super.init(context: context)
    }

    func toolIcon(for toolName: String?) -> String? {
        guard let toolName else { return nil }
        return context.feature(MCPServersFeature.self)
            .listToolDefinitions()
            .first(where: { $0.name == toolName })?
            .icon
    }
}
