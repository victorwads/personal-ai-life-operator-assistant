import Foundation

@MainActor
final class GoogleWorkspaceFeature: FeatureRuntime {
    override class var id: String { "googleWorkspace" }

    private(set) var settings: GoogleWorkspaceSettingsWrapper
    private(set) var tokenStore: GoogleOAuthTokenStore
    private(set) var authService: GoogleOAuthService
    private(set) var httpClient: GoogleWorkspaceHTTPClient
    private(set) var gmailService: GmailService
    private(set) var calendarService: GoogleCalendarService
    private(set) var contactsService: GoogleContactsService

    required init(context: FeatureContext) {
        let settings = GoogleWorkspaceSettingsWrapper(settings: context.settings.store)
        self.settings = settings
        
        let tokenStore = GoogleOAuthTokenStore(settingsStore: context.settings.store)
        self.tokenStore = tokenStore
        
        let authService = GoogleOAuthService(settings: settings, tokenStore: tokenStore)
        self.authService = authService
        
        let httpClient = GoogleWorkspaceHTTPClient(authService: authService)
        self.httpClient = httpClient
        
        self.gmailService = GmailService(httpClient: httpClient)
        self.calendarService = GoogleCalendarService(httpClient: httpClient)
        self.contactsService = GoogleContactsService(httpClient: httpClient)

        super.init(context: context)

        // Register settings section
        context.settings.sectionRegistry.register(
            GoogleWorkspaceSettingsSectionProvider(
                wrapper: settings,
                authStatusProvider: { [weak self] in
                    self?.authService.state ?? .disconnected
                }
            )
        )

        // Register MCP tools
        context.mcp.toolRegistry.register([
            ListGmailEmailsTool(serviceProvider: { [weak self] in
                guard let self else { fatalError("GoogleWorkspaceFeature deallocated") }
                return self.gmailService
            }),
            ListCalendarEventsTool(serviceProvider: { [weak self] in
                guard let self else { fatalError("GoogleWorkspaceFeature deallocated") }
                return self.calendarService
            }),
            SearchGoogleContactsTool(serviceProvider: { [weak self] in
                guard let self else { fatalError("GoogleWorkspaceFeature deallocated") }
                return self.contactsService
            }),
            GoogleWorkspaceAuthStatusTool(
                authServiceProvider: { [weak self] in
                    guard let self else { fatalError("GoogleWorkspaceFeature deallocated") }
                    return self.authService
                },
                settingsProvider: { [weak self] in
                    guard let self else { fatalError("GoogleWorkspaceFeature deallocated") }
                    return self.settings
                }
            )
        ])
    }
}
