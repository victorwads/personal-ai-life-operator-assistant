import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var trayAccounts: [WhatsAppWebAccount] = []
    private var isRefreshingTrayAccounts = false
    private var didBootstrapAutoStartProfiles = false
    private var trayObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_: Notification) {
        FirebaseBootstrap.shared.configure()
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        installTrayObservers()
        Task { await refreshTrayAccounts() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ProfileWindowManager.shared.prepareForTermination()
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }

        guard ProfileWindowManager.shared.isHomeWindowVisible else {
            return false
        }

        ProfileWindowManager.shared.showHomeWindow()
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildStatusMenu()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(named: "TrayIcon") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Assistant MCP")
        }
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Assistant MCP"

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem
        statusMenu = menu
        rebuildStatusMenu()
    }

    private func installTrayObservers() {
        let center = NotificationCenter.default
        let handlers: [(Notification.Name, NSObjectProtocol)] = [
            (
                .whatsAppWebAccountsRepositoryDidChange,
                center.addObserver(forName: .whatsAppWebAccountsRepositoryDidChange, object: nil, queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        await self?.refreshTrayAccounts()
                    }
                }
            )
        ]

        trayObservers = handlers.map(\.1)
    }

    private func rebuildStatusMenu() {
        guard let menu = statusMenu else { return }

        menu.removeAllItems()

        let headerItem = NSMenuItem(title: "Assistant MCP", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let profilesHeader = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
        profilesHeader.isEnabled = false
        menu.addItem(profilesHeader)

        if isRefreshingTrayAccounts && trayAccounts.isEmpty {
            let loadingItem = NSMenuItem(title: "Loading profiles...", action: nil, keyEquivalent: "")
            loadingItem.isEnabled = false
            menu.addItem(loadingItem)
        } else if trayAccounts.isEmpty {
            let emptyItem = NSMenuItem(title: "No profiles available", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, account) in trayAccounts.enumerated() {
                menu.addItem(makeProfileMenuItem(for: account, index: index))
            }
        }

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: ProfileWindowManager.shared.isHomeWindowVisible ? "Hide Profiles Window" : "Show Profiles Window",
            action: #selector(toggleProfilesWindow),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let showAllItem = NSMenuItem(title: "Show All Managed Windows", action: #selector(showAllManagedWindows), keyEquivalent: "")
        showAllItem.target = self
        menu.addItem(showAllItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Assistant MCP", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeProfileMenuItem(for account: WhatsAppWebAccount, index: Int) -> NSMenuItem {
        let appProfile = appProfile(for: account)
        let isRunning = ProfileWindowManager.shared.isProfileRunning(profileId: appProfile.id)
        let isVisible = ProfileWindowManager.shared.isProfileWindowVisible(profileId: appProfile.id)

        let menuItem = NSMenuItem(
            title: appProfile.displayName.isEmpty ? account.name : appProfile.displayName,
            action: nil,
            keyEquivalent: ""
        )
        menuItem.submenu = makeProfileSubmenu(
            for: account,
            profile: appProfile,
            index: index,
            isRunning: isRunning,
            isVisible: isVisible
        )
        return menuItem
    }

    private func makeProfileSubmenu(
        for account: WhatsAppWebAccount,
        profile: AppProfile,
        index: Int,
        isRunning: Bool,
        isVisible: Bool
    ) -> NSMenu {
        let submenu = NSMenu(title: profile.displayName)

        let statusItem = NSMenuItem(title: "Status: \(profileStatusText(isRunning: isRunning, isVisible: isVisible, autoStart: account.isAutoStart))", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        submenu.addItem(statusItem)

        let autoStartItem = NSMenuItem(title: "Auto start", action: #selector(toggleProfileAutoStart(_:)), keyEquivalent: "")
        autoStartItem.target = self
        autoStartItem.representedObject = account.id.uuidString
        autoStartItem.state = account.isAutoStart ? .on : .off
        submenu.addItem(autoStartItem)

        submenu.addItem(.separator())

        let openOrStartTitle = isRunning ? "Open Window" : "Start"
        let openOrStartItem = NSMenuItem(title: openOrStartTitle, action: #selector(openOrStartProfile(_:)), keyEquivalent: "")
        openOrStartItem.target = self
        openOrStartItem.representedObject = account.id.uuidString
        submenu.addItem(openOrStartItem)

        if isRunning {
            let stopItem = NSMenuItem(title: "Stop", action: #selector(stopProfile(_:)), keyEquivalent: "")
            stopItem.target = self
            stopItem.representedObject = account.id.uuidString
            submenu.addItem(stopItem)
        }

        let detailsItem = NSMenuItem(title: "Port: \(basePort(for: index))", action: nil, keyEquivalent: "")
        detailsItem.isEnabled = false
        submenu.addItem(.separator())
        submenu.addItem(detailsItem)

        return submenu
    }

    private func profileStatusText(isRunning: Bool, isVisible: Bool, autoStart: Bool) -> String {
        if isRunning {
            let base = isVisible ? "Running" : "Running in background"
            return autoStart ? "\(base) • Auto start on" : base
        }
        return autoStart ? "Stopped • Auto start on" : "Stopped"
    }

    private func appProfile(for account: WhatsAppWebAccount) -> AppProfile {
        AppProfile.forWhatsAppWebAccount(account, isDefault: false)
    }

    private func basePort(for index: Int) -> Int {
        let storedBasePort = UserDefaults.standard.integer(forKey: "mcpServer.basePort.v1")
        let basePort = (1024...65535).contains(storedBasePort) ? storedBasePort : 8080
        return basePort + index
    }

    private func account(for sender: NSMenuItem) -> WhatsAppWebAccount? {
        guard let profileId = sender.representedObject as? String else {
            return nil
        }

        return trayAccounts.first(where: { appProfile(for: $0).id == profileId })
    }

    private func refreshTrayAccounts() async {
        guard !isRefreshingTrayAccounts else { return }
        isRefreshingTrayAccounts = true
        defer {
            isRefreshingTrayAccounts = false
        }

        let profiles = await AppProfilesRepository.shared.loadOrCreateDefaultProfiles()
        let accounts = await WhatsAppWebAccountsRepository.shared.loadOrCreateAccounts(for: profiles)
        trayAccounts = accounts
        await bootstrapAutoStartProfilesIfNeeded()
        rebuildStatusMenu()
    }

    private func bootstrapAutoStartProfilesIfNeeded() async {
        guard !didBootstrapAutoStartProfiles else { return }
        guard !trayAccounts.isEmpty else { return }

        didBootstrapAutoStartProfiles = true

        for (index, account) in trayAccounts.enumerated() where account.isAutoStart {
            let profile = appProfile(for: account)
            guard !ProfileWindowManager.shared.isProfileRunning(profileId: profile.id) else {
                continue
            }

            let model = AppModel(
                profile: profile,
                profileIndex: index,
                basePort: basePort(for: index),
                primaryWhatsAppWebAccountId: account.id,
                startupMode: .live
            )
            ProfileWindowManager.shared.startBackgroundProfile(profile: profile, appModel: model)
        }
    }

    @objc
    private func toggleProfilesWindow() {
        if ProfileWindowManager.shared.isHomeWindowVisible {
            ProfileWindowManager.shared.hideHomeWindow()
        } else {
            ProfileWindowManager.shared.showHomeWindow()
        }
        rebuildStatusMenu()
    }

    @objc
    private func showAllManagedWindows() {
        ProfileWindowManager.shared.showAllManagedWindows()
        rebuildStatusMenu()
    }

    @objc
    private func openOrStartProfile(_ sender: NSMenuItem) {
        guard let account = account(for: sender) else { return }
        let profile = appProfile(for: account)
        guard let index = trayAccounts.firstIndex(where: { appProfile(for: $0).id == profile.id }) else {
            return
        }

        ProfileWindowManager.shared.showMainWindow(
            profile: profile,
            appModel: AppModel(
                profile: profile,
                profileIndex: index,
                basePort: basePort(for: index),
                primaryWhatsAppWebAccountId: account.id,
                startupMode: .live
            )
        )
    }

    @objc
    private func stopProfile(_ sender: NSMenuItem) {
        guard let account = account(for: sender) else { return }
        let profileId = appProfile(for: account).id

        Task {
            await ProfileWindowManager.shared.stopMainWindow(profileId: profileId)
            await refreshTrayAccounts()
        }
    }

    @objc
    private func toggleProfileAutoStart(_ sender: NSMenuItem) {
        guard let account = account(for: sender) else { return }

        Task {
            _ = await WhatsAppWebAccountsRepository.shared.updateAutoStart(id: account.id, isAutoStart: !account.isAutoStart)
            await refreshTrayAccounts()
        }
    }

    @objc
    private func quitApp() {
        ProfileWindowManager.shared.prepareForTermination()
        NSApp.terminate(nil)
    }
}
