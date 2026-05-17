import SwiftUI

@main
struct AssistantMCPServerApp: App {
    @StateObject private var appModel: AppModel
    @State private var didOpenSecondaryWindows = false

    init() {
        let storedBasePort = UserDefaults.standard.integer(forKey: "mcpServer.basePort.v1")
        let basePort = (1024...65535).contains(storedBasePort) ? storedBasePort : 8080
        let accounts = WhatsAppWebAccountsBootstrap.peekAccounts()
        let sortedAccounts = accounts.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        let firstAccount = sortedAccounts.first
        let firstAccountId = firstAccount?.id
        let defaultProfile = firstAccount.map { AppProfile.defaultNamed($0.name) } ?? .default
        _appModel = StateObject(wrappedValue: AppModel(
            profile: defaultProfile,
            profileIndex: 0,
            basePort: basePort,
            primaryWhatsAppWebAccountId: firstAccountId
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 980, minHeight: 680)
                .task {
                    guard !didOpenSecondaryWindows else { return }
                    didOpenSecondaryWindows = true

                    let accounts = await WhatsAppWebAccountsRepository(defaults: .standard).list()
                    guard accounts.count > 1 else { return }

                    // The first account stays as the default window (no namespacing).
                    // Each next account opens its own window with port incremented by +1.
                    let basePort = appModel.mcpServerPort
                    for (index, account) in accounts.enumerated().dropFirst() {
                        let profile = AppProfile.forWhatsAppWebAccount(account, isDefault: false)
                        let model = AppModel(
                            profile: profile,
                            profileIndex: index,
                            basePort: basePort,
                            primaryWhatsAppWebAccountId: account.id
                        )
                        ProfileWindowManager.shared.showMainWindow(profile: profile, appModel: model)
                    }
                }
        }
        .windowStyle(.titleBar)
    }
}
