import Foundation

@MainActor
final class MCPServersFeature: FeatureRuntime {
    override class var id: String { "mcpServers" }

    private static let serviceId = "mcp.server"

    private(set) var settings: MCPServerSettingsWrapper
    private let toolExecutor: MCPToolExecutor

    required init(context: FeatureContext) {
        let settings = MCPServerSettingsWrapper(settings: context.settings.store)
        self.settings = settings
        self.toolExecutor = MCPToolExecutor(
            registry: context.mcp.toolRegistry,
            validators: [
                MCPRequiredFieldsValidator(),
                MCPUnknownFieldsValidator(),
                MCPArgumentTypeValidator(),
                MCPEnumValidator(),
                MCPIssueIdValidator(issueValidator: { context.feature(IssuesFeature.self) } )
            ]
        )
        super.init(context: context)

        var pendingWorkProviders: [any PendingWorkProvider] = []
        if let scope = context.profileContext.scope {
            pendingWorkProviders.append(
                ChatsPendingWorkProvider(repository: FirestoreChatRepository(scope: scope))
            )
        }

        context.mcp.toolRegistry.register([
            GetCurrentDateTimeTool(),
            WaitForEventTool(
                sharedLocks: context.sharedLocks,
                pendingWorkProviders: pendingWorkProviders
            )
        ])

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

    func listToolDefinitions() -> [any MCPToolDefinition] {
        context.mcp.toolRegistry.allDefinitions()
    }

    func executeToolCall(_ call: MCPToolCall) async -> MCPToolExecutionResult {
        await toolExecutor.execute(call)
    }
}
