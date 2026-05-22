import SwiftUI
import WebKit

struct WhatsAppWebScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var captureNameDraft = ""

    var body: some View {
        detail
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await appModel.loadWhatsAppWebAccounts()
            }
    }

    @ViewBuilder
    private var detail: some View {
        if let account = appModel.selectedWhatsAppWebAccount {
            let isIntegrationActive = appModel.isPolling || appModel.isSendingMessage
            let isDetached = appModel.isWhatsAppWebDetached(account.id)

            if isDetached {
                detachedState(account: account)
            } else {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("https://web.whatsapp.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Image(systemName: isIntegrationActive ? "lock.fill" : "lock.open")
                            Text(isIntegrationActive ? "Locked (integration running)" : "Unlocked (click the badge to resume integration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        appModel.detachWhatsAppWebAccount(account)
                    } label: {
                        Label("Detach WebView", systemImage: "arrow.up.left.and.arrow.down.right")
                    }

                    if appModel.developerModeSettings.isEnabled {
                        TextField("Capture name", text: $captureNameDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)

                        Button {
                            Task {
                                await appModel.captureWhatsAppWebSnapshot(for: account)
                            }
                        } label: {
                            Label("Refresh Snapshot", systemImage: "arrow.clockwise.circle")
                        }

                        Button {
                            Task {
                                await appModel.forceUpdateSelectedWhatsAppWebChat(for: account)
                            }
                        } label: {
                            Label("Update This Chat", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Button {
                            Task {
                                let trimmedName = captureNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                await appModel.captureAndSaveWhatsAppWebSnapshot(for: account, named: trimmedName.isEmpty ? nil : trimmedName)
                                captureNameDraft = ""
                            }
                        } label: {
                            Label("Save Snapshot", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            appModel.whatsAppWebDebugCaptureService.revealCapturesDirectoryInFinder()
                        } label: {
                            Label("Open Captures Folder", systemImage: "folder")
                        }
                    }
                }
                .padding(12)

                Divider()

                ZStack {
                    WhatsAppWebView(
                        webView: appModel.whatsAppWebSessionStore.webView(for: account),
                        mode: isIntegrationActive ? .bridgePolling : .interactive,
                        pollingPageZoom: appModel.whatsAppWebSettings.pageZoom
                    )
                    .id(account.id)
                    .allowsHitTesting(!isIntegrationActive)

                    if isIntegrationActive {
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 46, weight: .semibold))

                            Text("Locked")
                                .font(.title2.weight(.semibold))

                            Text("Stop integration to use this screen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                appModel.stopPolling()
                            } label: {
                                Label("Stop Integration", systemImage: "pause.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(appModel.isSendingMessage)
                        }
                        .padding(18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if appModel.developerModeSettings.isEnabled, let snapshot = appModel.selectedWhatsAppWebPageSnapshot {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bridge Snapshot")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("State: \(snapshot.documentReadyState) • Flow: \(snapshot.flow.rawValue) • Logged in: \(snapshot.isLoggedIn ? "yes" : "no") • Chats: \(snapshot.chatRowCount) • Unread markers: \(snapshot.unreadBadgeCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let selectedChatTitle = snapshot.selectedChatTitle, !selectedChatTitle.isEmpty {
                            Text("Selected chat: \(selectedChatTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let composePlaceholder = snapshot.composePlaceholder, !composePlaceholder.isEmpty {
                            Text("Composer: \(composePlaceholder)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
            }
            }
        } else {
            ContentUnavailableView(
                "No WhatsApp Web account",
                systemImage: "globe",
                description: Text("Create an account from the home screen to keep a WhatsApp Web session running in the background.")
            )
        }
    }

    @ViewBuilder
    private func detachedState(account: WhatsAppWebAccount) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("WebView detached")
                    .font(.title3.weight(.semibold))
                Text("This WhatsApp Web session is open in a separate window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                appModel.closeDetachedWhatsAppWebWindow(accountId: account.id)
            } label: {
                Label("Return to sidebar", systemImage: "sidebar.left")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct WhatsAppWebView: NSViewRepresentable {
    enum Mode: Equatable {
        case bridgePolling
        case interactive
    }

    let webView: WKWebView
    let mode: Mode
    let pollingPageZoom: Double

    func makeNSView(context: Context) -> NSView {
        let container = WhatsAppWebFitContainer(
            webView: webView,
            fixedViewportSize: Self.fixedViewportSize,
            mode: mode,
            pollingPageZoom: pollingPageZoom
        )
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        (container as? WhatsAppWebFitContainer)?.fixedViewportSize = Self.fixedViewportSize
        (container as? WhatsAppWebFitContainer)?.mode = mode
        (container as? WhatsAppWebFitContainer)?.pollingPageZoom = pollingPageZoom
        (container as? WhatsAppWebFitContainer)?.applyInteractionLock(mode == .bridgePolling)
        container.needsLayout = true
    }

    static var fixedViewportSize: NSSize {
        // 1080p logical viewport works well for stable parsing and consistent element geometry.
        NSSize(width: 1920, height: 1080)
    }
}

final class WhatsAppWebFitContainer: NSView {
    private let webView: WKWebView
    var fixedViewportSize: NSSize {
        didSet {
            needsLayout = true
        }
    }
    var mode: WhatsAppWebView.Mode {
        didSet {
            needsLayout = true
        }
    }
    var pollingPageZoom: Double {
        didSet {
            needsLayout = true
        }
    }

    init(
        webView: WKWebView,
        fixedViewportSize: NSSize,
        mode: WhatsAppWebView.Mode,
        pollingPageZoom: Double
    ) {
        self.webView = webView
        self.fixedViewportSize = fixedViewportSize
        self.mode = mode
        self.pollingPageZoom = pollingPageZoom
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.masksToBounds = true

        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.wantsLayer = true
        webView.setFrameSize(fixedViewportSize)

        addSubview(webView)

        // SwiftUI often sets the final size after `makeNSView` returns. Force a first
        // layout pass on the next runloop so the initial "scale-to-fit" is applied
        // without requiring a manual window resize.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
            self.applyInteractionLock(self.mode == .bridgePolling)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let availableSize = bounds.size
        guard availableSize.width > 0, availableSize.height > 0 else { return }
        guard fixedViewportSize.width > 0, fixedViewportSize.height > 0 else { return }

        switch mode {
        case .bridgePolling:
            // Keep the logical viewport fixed (stable for automation/parsing),
            // but scale the rendered view so it fits the available area.
            webView.pageZoom = min(max(pollingPageZoom, 0.25), 2.0)

            let scaleX = availableSize.width / fixedViewportSize.width
            let scaleY = availableSize.height / fixedViewportSize.height
            let scale = max(min(min(scaleX, scaleY), 1.0), 0.05)

            webView.frame = NSRect(origin: .zero, size: fixedViewportSize)

            if let layer = webView.layer {
                layer.anchorPoint = CGPoint(x: 0, y: 1)
                layer.position = CGPoint(x: 0, y: bounds.height)
                layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
            }
        case .interactive:
            // Let the view fill the container for manual interaction.
            webView.pageZoom = 1.0
            webView.frame = bounds
            if let layer = webView.layer {
                layer.anchorPoint = CGPoint(x: 0, y: 0)
                layer.position = CGPoint(x: 0, y: 0)
                layer.setAffineTransform(.identity)
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
            self.applyInteractionLock(self.mode == .bridgePolling)
        }
    }

    func applyInteractionLock(_ isLocked: Bool) {
        if isLocked {
            webView.evaluateJavaScript(WhatsAppWebJavaScript.installLockOverlayScript, completionHandler: nil)
            if webView.window?.firstResponder === webView {
                webView.window?.makeFirstResponder(nil)
            }
        } else {
            webView.evaluateJavaScript(WhatsAppWebJavaScript.removeLockOverlayScript, completionHandler: nil)
        }
    }
}

#Preview {
    WhatsAppWebScreen()
        .environmentObject(AppModel.preview)
        .frame(width: 1100, height: 720)
}
