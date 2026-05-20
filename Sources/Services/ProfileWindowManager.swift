import AppKit
import SwiftUI

@MainActor
final class ProfileWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = ProfileWindowManager()

    private enum StorageKey {
        static let homeWindowVisible = "assistant.window.home.visible.v1"
        static let visibleProfileIds = "assistant.window.profile.visibleIds.v1"
    }

    private var controllersByProfileId: [String: NSWindowController] = [:]
    private var appModelsByProfileId: [String: AppModel] = [:]
    private var profileIdsByWindowId: [ObjectIdentifier: String] = [:]
    private weak var homeWindow: NSWindow?
    private var homeWindowId: ObjectIdentifier?
    private var closingProfileIds: Set<String> = []
    private let defaults: UserDefaults = .standard
    @Published private(set) var runningProfileIds: Set<String> = []
    @Published private(set) var visibleProfileIds: Set<String> = []
    @Published private(set) var isHomeWindowVisible = true

    override init() {
        isHomeWindowVisible = defaults.object(forKey: StorageKey.homeWindowVisible) as? Bool ?? true
        let storedVisibleProfileIds = defaults.stringArray(forKey: StorageKey.visibleProfileIds) ?? []
        visibleProfileIds = Set(storedVisibleProfileIds)
        super.init()
    }

    func showMainWindow(profile: AppProfile, appModel: AppModel) {
        if let existing = controllersByProfileId[profile.id], let window = existing.window {
            runningProfileIds.insert(profile.id)
            setProfileWindowVisible(profile.id, true)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        appModelsByProfileId[profile.id] = appModel

        let rootView = ContentView()
            .environmentObject(appModel)
            .frame(minWidth: 980, minHeight: 680)

        let hosting = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Assistant MCP — \(profile.displayName)"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.delegate = self
        profileIdsByWindowId[ObjectIdentifier(window)] = profile.id
        runningProfileIds.insert(profile.id)
        setProfileWindowVisible(profile.id, true)

        let controller = NSWindowController(window: window)
        controllersByProfileId[profile.id] = controller

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func revealMainWindow(profileId: String) {
        guard let controller = controllersByProfileId[profileId], let window = controller.window else {
            return
        }

        runningProfileIds.insert(profileId)
        setProfileWindowVisible(profileId, true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showHomeWindow() {
        isHomeWindowVisible = true
        persistHomeWindowVisibility()

        guard let homeWindow else {
            return
        }

        homeWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func registerHomeWindow(_ window: NSWindow) {
        if homeWindowId == ObjectIdentifier(window) {
            return
        }

        homeWindow = window
        homeWindowId = ObjectIdentifier(window)
        window.isReleasedWhenClosed = false
        window.delegate = self
        applyHomeWindowVisibility()
    }

    func restoreVisibleProfileWindows(accounts: [WhatsAppWebAccount], basePort: Int) {
        let accountsByProfileId = Dictionary(uniqueKeysWithValues: accounts.enumerated().map { index, account in
            (AppProfile.forWhatsAppWebAccount(account, isDefault: false).id, (account: account, index: index))
        })

        for profileId in Array(visibleProfileIds) {
            guard controllersByProfileId[profileId] == nil,
                  let entry = accountsByProfileId[profileId] else {
                continue
            }

            let profile = AppProfile.forWhatsAppWebAccount(entry.account, isDefault: false)
            let model = AppModel(
                profile: profile,
                profileIndex: entry.index,
                basePort: basePort,
                primaryWhatsAppWebAccountId: entry.account.id,
                startupMode: .live
            )
            showMainWindow(profile: profile, appModel: model)
        }
    }

    func showAllManagedWindows() {
        showHomeWindow()

        for profileId in Array(runningProfileIds) {
            revealMainWindow(profileId: profileId)
        }
    }

    func isProfileWindowVisible(profileId: String) -> Bool {
        visibleProfileIds.contains(profileId)
    }

    func stopMainWindow(profileId: String) async {
        closingProfileIds.insert(profileId)
        defer { closingProfileIds.remove(profileId) }

        guard let controller = controllersByProfileId.removeValue(forKey: profileId) else {
            runningProfileIds.remove(profileId)
            setProfileWindowVisible(profileId, false)
            let appModel = appModelsByProfileId.removeValue(forKey: profileId)
            await appModel?.shutdown()
            return
        }

        runningProfileIds.remove(profileId)
        setProfileWindowVisible(profileId, false)
        let appModel = appModelsByProfileId.removeValue(forKey: profileId)
        if let window = controller.window {
            profileIdsByWindowId.removeValue(forKey: ObjectIdentifier(window))
        }

        await appModel?.shutdown()
        controller.close()
    }

    func isProfileRunning(profileId: String) -> Bool {
        runningProfileIds.contains(profileId)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let windowId = ObjectIdentifier(sender)
        if let homeWindowId, windowId == homeWindowId {
            isHomeWindowVisible = false
            persistHomeWindowVisibility()
            sender.orderOut(nil)
            return false
        }

        guard let profileId = profileIdsByWindowId[windowId] else {
            return true
        }

        if closingProfileIds.contains(profileId) {
            return true
        }

        setProfileWindowVisible(profileId, false)
        sender.orderOut(nil)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        let windowId = ObjectIdentifier(window)
        if homeWindowId == windowId {
            homeWindow = nil
            homeWindowId = nil
            isHomeWindowVisible = false
            persistHomeWindowVisibility()
            return
        }

        guard let profileId = profileIdsByWindowId.removeValue(forKey: windowId) else {
            return
        }

        runningProfileIds.remove(profileId)
        visibleProfileIds.remove(profileId)
        persistVisibleProfileIds()
        controllersByProfileId.removeValue(forKey: profileId)

        let appModel = appModelsByProfileId.removeValue(forKey: profileId)
        Task { await appModel?.shutdown() }
    }

    private func setProfileWindowVisible(_ profileId: String, _ isVisible: Bool) {
        if isVisible {
            visibleProfileIds.insert(profileId)
        } else {
            visibleProfileIds.remove(profileId)
        }
        persistVisibleProfileIds()
    }

    private func applyHomeWindowVisibility() {
        if isHomeWindowVisible {
            homeWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            homeWindow?.orderOut(nil)
        }
    }

    private func persistHomeWindowVisibility() {
        defaults.set(isHomeWindowVisible, forKey: StorageKey.homeWindowVisible)
    }

    private func persistVisibleProfileIds() {
        defaults.set(Array(visibleProfileIds).sorted(), forKey: StorageKey.visibleProfileIds)
    }
}
