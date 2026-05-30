import Foundation

@MainActor
final class IssuesFeature: FeatureRuntime {
    override class var id: String { "issues" }

    required init(context: FeatureContext) {
        super.init(context: context)
        context.mcp.toolRegistry.register(provider: IssuesMCPToolProvider())
    }
}
