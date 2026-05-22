import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedScreen: SidebarScreen = .whatsAppChats
    @State private var selectedSubjectId: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    enum SidebarScreen: Hashable, Identifiable {
        case nicknames
        case subjects
        case memories
        case sensitiveData
        case clientVoice
        case whatsAppChats
        case whatsAppWebAccount(UUID)
        case integrationLogs
        case integrationDebug
        case integrationYAMLTree
        case serverLogs
        case lmStudio
        case serverTools
        case settings

        var id: String {
            switch self {
            case .nicknames: "nicknames"
            case .subjects: "subjects"
            case .memories: "memories"
            case .sensitiveData: "sensitiveData"
            case .clientVoice: "clientVoice"
            case .whatsAppChats: "whatsAppChats"
            case .whatsAppWebAccount(let id): "whatsAppWebAccount:\(id.uuidString)"
            case .integrationLogs: "integrationLogs"
            case .integrationDebug: "integrationDebug"
            case .integrationYAMLTree: "integrationYAMLTree"
            case .serverLogs: "serverLogs"
            case .lmStudio: "lmStudio"
            case .serverTools: "serverTools"
            case .settings: "settings"
            }
        }

        var defaultTitle: String {
            switch self {
            case .nicknames: "Nicknames"
            case .subjects: "Subjects"
            case .memories: "Memories"
            case .sensitiveData: "Sensitive Data"
            case .clientVoice: "Client Voice"
            case .whatsAppChats: "Chats"
            case .whatsAppWebAccount: "WebView"
            case .integrationLogs: "Logs"
            case .integrationDebug: "Debug"
            case .integrationYAMLTree: "YAML Tree"
            case .serverLogs: "Logs"
            case .lmStudio: "LM Studio"
            case .serverTools: "Tools"
            case .settings: "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .nicknames: "tag"
            case .subjects: "checklist"
            case .memories: "brain"
            case .sensitiveData: "lock.shield"
            case .clientVoice: "waveform"
            case .whatsAppChats: "bubble.left.and.bubble.right"
            case .whatsAppWebAccount: "globe"
            case .integrationLogs: "list.bullet.rectangle"
            case .integrationDebug: "point.3.connected.trianglepath.dotted"
            case .integrationYAMLTree: "doc.badge.gearshape"
            case .serverLogs: "server.rack"
            case .lmStudio: "cpu"
            case .serverTools: "wrench.and.screwdriver"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedScreen) {
                Section("Data") {
                    sidebarItem(.nicknames)
                    sidebarItem(.subjects)
                    sidebarItem(.memories)
                    sidebarItem(.sensitiveData)
                    sidebarItem(.clientVoice)
                }

                Section("WhatsApp Integration") {
                    sidebarItem(.whatsAppChats)

                    if appModel.whatsAppIntegrationSettings.mode == .web {
                        ForEach(appModel.activeWhatsAppWebAccounts) { account in
                            sidebarItem(.whatsAppWebAccount(account.id))
                        }
                    } else {
                        if appModel.developerModeSettings.isEnabled {
                            sidebarItem(.integrationDebug, title: "Accessibility Tree")
                        }
                    }

                    if appModel.developerModeSettings.isEnabled {
                        sidebarItem(.integrationYAMLTree, title: "YAML Tree")
                    }

                    if appModel.developerModeSettings.isEnabled {
                        // Logs should always be last in this section.
                        sidebarItem(.integrationLogs)
                    }
                }

                Section("Server") {
                    if appModel.developerModeSettings.isEnabled {
                        sidebarItem(.serverLogs)
                    }
                    sidebarItem(.lmStudio)
                    sidebarItem(.serverTools)
                }

                Section("Settings") {
                    sidebarItem(.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 360)
            .navigationTitle("Assistant MCP")
        } detail: {
            VStack(spacing: 0) {
                headerBar
                Divider()
                selectedDetailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: appModel.whatsAppIntegrationSettings.mode) { _, newMode in
            // If the user switches integration mode, ensure the currently selected screen still exists
            // in the sidebar for that mode.
            switch newMode {
            case .desktopAX:
                if case .whatsAppWebAccount = selectedScreen {
                    selectedScreen = .whatsAppChats
                }
            case .web:
                if selectedScreen == .integrationDebug {
                    selectedScreen = .whatsAppChats
                }
            }
        }
        .onChange(of: appModel.developerModeSettings.isEnabled) { _, isEnabled in
            guard !isEnabled else { return }

            switch selectedScreen {
            case .integrationLogs, .integrationDebug, .integrationYAMLTree:
                selectedScreen = .whatsAppChats
            case .serverLogs:
                selectedScreen = .lmStudio
            default:
                break
            }
        }
        .onChange(of: selectedScreen) { _, newScreen in
            if case .whatsAppWebAccount(let accountId) = newScreen {
                appModel.selectedWhatsAppWebAccountId = accountId
            }
        }
    }

    private var selectedDetailView: some View {
        Group {
            switch selectedScreen {
            case .nicknames:
                NicknamesScreen()
            case .subjects:
                SubjectsScreen(selectedSubjectId: $selectedSubjectId)
            case .memories:
                MemoriesScreen()
            case .sensitiveData:
                SensitiveDataScreen { subjectId in
                    if let subjectUUID = UUID(uuidString: subjectId) {
                        selectedSubjectId = subjectUUID
                    }
                    selectedScreen = .subjects
                }
            case .clientVoice:
                ClientVoiceScreen()
            case .whatsAppChats:
                ConversationsScreen()
            case .whatsAppWebAccount(let accountId):
                WhatsAppWebScreen()
            case .settings:
                SettingsScreen(
                    appModel: appModel,
                    voiceSettings: appModel.voiceSettings,
                    handsFreeClientVoiceSettings: appModel.handsFreeClientVoiceSettings,
                    inputLockSettings: appModel.inputLockSettings,
                    mcpSendPrefixSettings: appModel.mcpSendPrefixSettings,
                    whatsAppWebSettings: appModel.whatsAppWebSettings,
                    whatsAppIntegrationSettings: appModel.whatsAppIntegrationSettings,
                    developerModeSettings: appModel.developerModeSettings
                )
                    .padding(12)
            case .integrationLogs:
                LogsScreen()
            case .integrationDebug:
                DebugTreeScreen(
                    captureService: appModel.whatsAppDebugService,
                    accessibility: appModel.accessibility
                )
            case .integrationYAMLTree:
                switch appModel.whatsAppIntegrationSettings.mode {
                case .web:
                    WhatsAppWebYAMLTreeTesterScreen()
                case .desktopAX:
                    WhatsAppNativeYAMLTreeTesterScreen()
                }
            case .serverLogs:
                ServerLogsScreen()
            case .lmStudio:
                LMStudioScreen(
                    lmStudio: appModel.lmStudio,
                    mcpServerURL: appModel.mcpServerMCPURL
                )
            case .serverTools:
                ServerToolsScreen()
            }
        }
    }

    private func sidebarItem(_ screen: SidebarScreen, title: String? = nil) -> some View {
        Label(title ?? screen.defaultTitle, systemImage: screen.systemImage)
            .tag(screen)
    }

    private var selectedScreenTitle: String {
        switch selectedScreen {
        case .whatsAppWebAccount(let accountId):
            return appModel.whatsAppWebAccounts.first(where: { $0.id == accountId })?.name ?? selectedScreen.defaultTitle
        default:
            return selectedScreen.defaultTitle
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Text(selectedScreenTitle)
                .font(.title3.weight(.semibold))

            Spacer()

            SpeechStatusBadge(
                isSpeaking: appModel.speechSynthesizerSpeaking,
                onStop: {
                    Task { await appModel.voiceAssistant.stopSpeaking() }
                }
            )

            PendingClientResponseBadge(
                pendingCount: appModel.pendingClientAskCount,
                onOpen: {
                    Task {
                        await appModel.openPendingClientAskWindow()
                    }
                },
                title: "Client response pending",
                dotColor: .orange,
                dotStrokeColor: nil,
                backgroundColor: Color.orange.opacity(0.12),
                helpText: "Open pending client ask"
            )

            WaitingForEventBadge(
                pendingCount: appModel.pendingClientPromptWaitCount,
                onOpen: {
                    appModel.openPendingClientPromptWindow()
                }
            )

            MicrophonePermissionBadge(
                isAuthorized: appModel.microphoneAuthorized,
                speechRecognitionAuthorized: appModel.speechRecognitionAuthorized,
                onRequestPermission: {
                    Task { await appModel.requestVoicePermissions() }
                }
            )

            BridgeStatusBadge(
                integrationMode: appModel.whatsAppIntegrationSettings.mode,
                isPolling: appModel.isPolling,
                isBusy: appModel.isSendingMessage,
                accessibilityTrusted: appModel.accessibilityTrusted,
                whatsappRunning: appModel.whatsappRunning,
                webSnapshot: appModel.selectedWhatsAppWebPageSnapshot,
                onRequestAccessibilityPermission: {
                    appModel.requestAccessibilityPermission()
                },
                onStartPolling: {
                    appModel.startPolling()
                }
            )

            MCPServerStatusBadge(
                isRunning: appModel.mcpServerRunning,
                address: appModel.mcpServerAddress,
                statusDescription: appModel.mcpServerStatusDescription
            )

            Text(appModel.lastRefreshDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel.preview)
        .frame(width: 980, height: 680)
}
