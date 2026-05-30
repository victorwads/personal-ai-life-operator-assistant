import Foundation

@MainActor
final class MCPServersFeature: FeatureRuntime {
    override class var id: String { "mcpServers" }

    private static let serviceId = "mcp.server"

    private(set) var settings: MCPServerSettingsWrapper

    required init(context: FeatureContext) {
        let settings = MCPServerSettingsWrapper(settings: context.settings.store)
        self.settings = settings
        super.init(context: context)

        context.mcp.toolRegistry.register(provider: MCPServersUtilityToolProvider())

        let service = PlaceholderProfileRuntimeService(
            id: Self.serviceId,
            title: "MCP Server"
        )

        context.services.serviceRegistry.register(service)

        context.status.statusRegistry.register(
            MCPServerRuntimeStatusProvider(
                service: service,
                port: context.profileContext.mcpPort
            )
        )
    }

    override func onStartServices() async {
        if settings.autoStart, let service = context.services.serviceRegistry.service(id: Self.serviceId) {
            await service.start()
        }
    }

    override func onStopServices() async {
        if let service = context.services.serviceRegistry.service(id: Self.serviceId) {
            await service.stop()
        }
    }
}
