import SwiftUI

struct WhatsAppWebYAMLDebugScreen: View {
    @ObservedObject var service: WebViewWhatsAppCrawlingService

    @State private var yamlText = ""
    @State private var resultJSON = ""
    @State private var errorMessage: String?
    @State private var isTesting = false

    var body: some View {
        Group {
            switch service.state {
            case .stopped:
                stateView(
                    title: "WebView is stopped",
                    description: "Start WebView to test YAML extraction.",
                    actionTitle: "Start",
                    action: { await service.start() }
                )
            case .starting:
                ProgressView("Starting WhatsApp WebView...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .stopping:
                ProgressView("Stopping WhatsApp WebView...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                stateView(
                    title: "WebView failed",
                    description: message,
                    actionTitle: "Start",
                    action: { await service.start() }
                )
            case .started:
                if service.webView == nil {
                    stateView(
                        title: "WebView unavailable",
                        description: "WebView is running but WKWebView is unavailable.",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    contentView
                }
            }
        }
        .task {
            guard yamlText.isEmpty else { return }
            await reloadYAML()
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button("Reload YAML") {
                    Task { await reloadYAML() }
                }
                .buttonStyle(.bordered)

                Button("Test") {
                    Task { await runTest() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting)

                Button("Clear Result") {
                    resultJSON = ""
                    errorMessage = nil
                }
                .buttonStyle(.bordered)

                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }
            .padding(12)

            Divider()

            HSplitView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YAML")
                        .font(.headline)
                    TextEditor(text: $yamlText)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(12)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Result JSON")
                        .font(.headline)
                    ScrollView {
                        Text(resultJSON.isEmpty ? "No result yet." : resultJSON)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                }
                .padding(12)
            }

            if let errorMessage {
                Divider()
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
    }

    private func reloadYAML() async {
        do {
            yamlText = try WebYAMLSelectorLoader.loadBundledYAML()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runTest() async {
        guard let webView = service.webView else {
            errorMessage = "WebView is running but WKWebView is unavailable."
            return
        }

        isTesting = true
        defer { isTesting = false }

        do {
            resultJSON = try await WebYAMLExtractionRunner.run(yamlText: yamlText, in: webView)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stateView(
        title: String,
        description: String,
        actionTitle: String?,
        action: (() async -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(description)
                .foregroundStyle(.secondary)

            if let actionTitle, let action {
                Button(actionTitle) {
                    Task { await action() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
