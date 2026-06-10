import Foundation

@MainActor
struct GoogleWorkspaceAuthStatusTool: MCPToolDefinition {
    private let authServiceProvider: @MainActor () -> GoogleOAuthService
    private let settingsProvider: @MainActor () -> GoogleWorkspaceSettingsWrapper

    init(
        authServiceProvider: @escaping @MainActor () -> GoogleOAuthService,
        settingsProvider: @escaping @MainActor () -> GoogleWorkspaceSettingsWrapper
    ) {
        self.authServiceProvider = authServiceProvider
        self.settingsProvider = settingsProvider
    }

    let name = "google_workspace_auth_status"
    let icon = "lock.shield"
    let description = "Checks Google Workspace authentication status, configured scopes, and settings warnings."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let authService = await authServiceProvider()
        let settings = await settingsProvider()

        var lines: [String] = ["<googleWorkspaceAuth>"]
        
        let clientId = settings.clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = settings.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        var warnings: [String] = []
        if clientId.isEmpty {
            warnings.append("ClientId is empty. Configure it in settings.")
        }
        if clientSecret.isEmpty {
            warnings.append("ClientSecret is empty. Configure it in settings.")
        }

        if !warnings.isEmpty {
            lines.append("  <warnings>")
            for warning in warnings {
                lines.append("    <warning>\(warning)</warning>")
            }
            lines.append("  </warnings>")
        }

        switch authService.state {
        case .disconnected:
            lines.append("  <status>Disconnected</status>")
        case .connecting(let state):
            lines.append("  <status>Connecting</status>")
            lines.append("  <connectingState>\(state)</connectingState>")
        case .connected(let scopes, let expiresAt):
            lines.append("  <status>Connected</status>")
            lines.append("  <scopes>\(scopes.joined(separator: " "))</scopes>")
            lines.append("  <tokenExpiration>\(ISO8601DateFormatter().string(from: expiresAt))</tokenExpiration>")
        }

        lines.append("</googleWorkspaceAuth>")

        return .string(lines.joined(separator: "\n"))
    }
}
