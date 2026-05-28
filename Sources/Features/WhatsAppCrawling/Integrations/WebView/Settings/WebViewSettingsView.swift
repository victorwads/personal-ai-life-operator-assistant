import SwiftUI

struct WhatsAppWebViewSettingsView: View {
    let wrapper: WhatsAppWebViewSettingsWrapper

    @State private var autoStart = false
    @State private var url = ""
    @State private var userAgent = ""
    @State private var userAgentAutoRefreshEnabled = false
    @State private var userAgentRefreshIntervalDays = 7
    @State private var userAgentCaptureError: String?
    @State private var isCapturingUserAgent = false
    @State private var lastUserAgentRefreshAt: Date?
    @State private var zoom = 1.0
    @State private var viewportWidth = 1080
    @State private var viewportHeight = 1920
    @State private var enableWebInspector = true
    @State private var websiteDataStoreIdentifier = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Auto Start WebView", isOn: autoStartBinding)
            TextField("URL", text: urlBinding)
            HStack(spacing: 8) {
                TextField("User Agent", text: userAgentBinding)
                Button {
                    Task {
                        await refreshUserAgentFromDefaultBrowser()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Capture User-Agent from default browser")
                .disabled(isCapturingUserAgent)
            }
            Toggle("Auto refresh User-Agent", isOn: userAgentAutoRefreshEnabledBinding)
            Stepper(
                "Refresh every \(userAgentRefreshIntervalDays) day\(userAgentRefreshIntervalDays == 1 ? "" : "s")",
                value: userAgentRefreshIntervalDaysBinding,
                in: 1...365
            )

            if let lastUserAgentRefreshAt {
                LabeledContent("Last User-Agent refresh") {
                    Text(lastUserAgentRefreshAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            if let userAgentCaptureError, !userAgentCaptureError.isEmpty {
                Text(userAgentCaptureError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Stepper("Zoom: \(zoom, specifier: "%.1f")", value: zoomBinding, in: 0.5...3.0, step: 0.1)
            Stepper("Viewport Width: \(viewportWidth)", value: viewportWidthBinding, in: 320...3840)
            Stepper("Viewport Height: \(viewportHeight)", value: viewportHeightBinding, in: 240...2160)
            Toggle("Enable Web Inspector", isOn: enableWebInspectorBinding)

            LabeledContent("Data Store") {
                Text(websiteDataStoreIdentifier.isEmpty ? "Generated on first start" : websiteDataStoreIdentifier)
                    .textSelection(.enabled)
            }
        }
        .task {
            load()
        }
    }

    private var autoStartBinding: Binding<Bool> {
        Binding {
            autoStart
        } set: { value in
            autoStart = value
            wrapper.autoStart = value
        }
    }

    private var zoomBinding: Binding<Double> {
        Binding {
            zoom
        } set: { value in
            zoom = value
            wrapper.zoom = value
        }
    }

    private var urlBinding: Binding<String> {
        Binding {
            url
        } set: { value in
            url = value
            wrapper.url = value
        }
    }

    private var userAgentBinding: Binding<String> {
        Binding {
            userAgent
        } set: { value in
            userAgent = value
            wrapper.userAgent = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        }
    }

    private var viewportWidthBinding: Binding<Int> {
        Binding {
            viewportWidth
        } set: { value in
            viewportWidth = value
            wrapper.viewportWidth = value
        }
    }

    private var userAgentAutoRefreshEnabledBinding: Binding<Bool> {
        Binding {
            userAgentAutoRefreshEnabled
        } set: { value in
            userAgentAutoRefreshEnabled = value
            wrapper.userAgentAutoRefreshEnabled = value
        }
    }

    private var userAgentRefreshIntervalDaysBinding: Binding<Int> {
        Binding {
            userAgentRefreshIntervalDays
        } set: { value in
            let normalized = max(1, value)
            userAgentRefreshIntervalDays = normalized
            wrapper.userAgentRefreshIntervalDays = normalized
        }
    }

    private var viewportHeightBinding: Binding<Int> {
        Binding {
            viewportHeight
        } set: { value in
            viewportHeight = value
            wrapper.viewportHeight = value
        }
    }

    private var enableWebInspectorBinding: Binding<Bool> {
        Binding {
            enableWebInspector
        } set: { value in
            enableWebInspector = value
            wrapper.enableWebInspector = value
        }
    }

    private func load() {
        autoStart = wrapper.autoStart
        url = wrapper.url
        userAgent = wrapper.userAgent ?? ""
        userAgentAutoRefreshEnabled = wrapper.userAgentAutoRefreshEnabled
        userAgentRefreshIntervalDays = wrapper.userAgentRefreshIntervalDays
        lastUserAgentRefreshAt = wrapper.lastUserAgentRefreshDate
        zoom = wrapper.zoom
        viewportWidth = wrapper.viewportWidth
        viewportHeight = wrapper.viewportHeight
        enableWebInspector = wrapper.enableWebInspector
        websiteDataStoreIdentifier = wrapper.websiteDataStoreIdentifier
    }

    private func refreshUserAgentFromDefaultBrowser() async {
        isCapturingUserAgent = true
        userAgentCaptureError = nil
        defer {
            isCapturingUserAgent = false
        }

        do {
            let service = BrowserUserAgentCaptureService()
            let capturedUserAgent = try await service.captureUserAgent()
            wrapper.userAgent = capturedUserAgent
            wrapper.lastUserAgentRefreshDate = Date()
            userAgent = capturedUserAgent
            lastUserAgentRefreshAt = wrapper.lastUserAgentRefreshDate
        } catch {
            userAgentCaptureError = error.localizedDescription
        }
    }
}
