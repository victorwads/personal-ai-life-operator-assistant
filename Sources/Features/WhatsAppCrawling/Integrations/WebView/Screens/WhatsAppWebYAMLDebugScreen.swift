import SwiftUI
import AppKit
import WebKit

struct WhatsAppWebYAMLDebugScreen: View {
    private struct ExtractedImagePreview: Identifiable {
        let id = UUID()
        let image: NSImage
        let mimeType: String?
        let width: Double?
        let height: Double?
        let source: String?
    }

    enum ResultViewMode: String, CaseIterable, Identifiable {
        case tree = "Tree"
        case rawJSON = "Raw JSON"
        var id: String { rawValue }
    }

    @ObservedObject var service: WebViewWhatsAppCrawlingService

    @State private var yamlText = ""
    @State private var resultJSON = ""
    @State private var resultObject: [String: Any]?
    @State private var expectedSpec: [String: Any] = ["web": [:], "flows": [:]]
    @State private var errorMessage: String?
    @State private var actionStatusMessage: String?
    @State private var typeText = ""
    @State private var isTesting = false
    @State private var resultViewMode: ResultViewMode = .tree
    @State private var autoTestTask: Task<Void, Never>?
    @State private var extractedImagePreview: ExtractedImagePreview?

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
        .onChange(of: yamlText) {
            scheduleAutoTestOnYAMLChange()
        }
        .onDisappear {
            autoTestTask?.cancel()
            autoTestTask = nil
        }
        .sheet(item: $extractedImagePreview) { preview in
            VStack(alignment: .leading, spacing: 12) {
                Image(nsImage: preview.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: 320, minHeight: 240)

                if let width = preview.width, let height = preview.height {
                    Text("Size: \(Int(width))x\(Int(height))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let mimeType = preview.mimeType, !mimeType.isEmpty {
                    Text("MIME: \(mimeType)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let source = preview.source, !source.isEmpty {
                    Text("Source: \(source)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack {
                    Spacer()
                    Button("Close") {
                        extractedImagePreview = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button("Reload YAML") { Task { await reloadYAML() } }
                    .buttonStyle(.bordered)

                Button("Test") { Task { await runTest() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTesting)

                Button("Clear Result") {
                    resultJSON = ""
                    resultObject = nil
                    errorMessage = nil
                    actionStatusMessage = nil
                }
                .buttonStyle(.bordered)

                if isTesting {
                    ProgressView().controlSize(.small)
                }

                Spacer()
            }
            .padding(12)

            Divider()

            HSplitView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("YAML")
                        .font(.headline)
                    PlainTextEditor(text: $yamlText)
                }
                .padding(12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Button("Tree") {
                                resultViewMode = .tree
                            }
                            .buttonStyle(.bordered)
                            .tint(resultViewMode == .tree ? .accentColor : .secondary)

                            Button("Raw JSON") {
                                resultViewMode = .rawJSON
                            }
                            .buttonStyle(.bordered)
                            .tint(resultViewMode == .rawJSON ? .accentColor : .secondary)
                        }

                        Spacer()
                    }
                    .frame(minHeight: 28)

                    if resultViewMode == .tree {
                        HStack(spacing: 8) {
                            Text("Text to type:")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .leading)
                            TextField("Type payload", text: $typeText)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(minHeight: 32)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                treeGroup(
                                    name: "web",
                                    expected: expectedSpec["web"] as? [String: Any] ?? [:],
                                    actual: resultObject?["web"] as? [String: Any]
                                )
                                treeGroup(
                                    name: "flows",
                                    expected: expectedSpec["flows"] as? [String: Any] ?? [:],
                                    actual: resultObject?["flows"] as? [String: Any]
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.trailing, 28)
                        }
                    } else {
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

            if let actionStatusMessage {
                Divider()
                Text(actionStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
    }

    private func treeGroup(name: String, expected: [String: Any], actual: [String: Any]?) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            ForEach(expected.keys.sorted(), id: \.self) { key in
                treeNode(
                    name: key,
                    expectedNode: expected[key],
                    actualValue: actual?[key],
                    level: 0
                )
            }
        })
    }

    private func treeNode(name: String, expectedNode: Any?, actualValue: Any?, level: Int) -> AnyView {
        let type = expectedType(from: expectedNode)
        let children = expectedChildren(from: expectedNode)
        let status = valueStatus(type: type, value: actualValue)
        return AnyView(VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.system(.body, design: .monospaced))
                Text(status.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let element = WebViewInteractiveElementDetector.from(actualValue as Any) {
                    Spacer(minLength: 8)
                    actionButtons(for: element)
                } else {
                    Spacer(minLength: 8)
                }
            }
            .padding(.leading, CGFloat(level) * 16)

            if let children {
                if type == "elements", let array = actualValue as? [Any], !array.isEmpty {
                    ForEach(Array(array.enumerated()), id: \.offset) { index, value in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.gray.opacity(0.6))
                                .frame(width: 8, height: 8)
                            Text("[\(index)]")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, CGFloat(level + 1) * 16)

                        ForEach(children.keys.sorted(), id: \.self) { childKey in
                            treeNode(
                                name: childKey,
                                expectedNode: children[childKey],
                                actualValue: (value as? [String: Any])?[childKey],
                                level: level + 2
                            )
                        }
                    }
                } else {
                    let objectValue = actualValue as? [String: Any]
                    ForEach(children.keys.sorted(), id: \.self) { childKey in
                        treeNode(
                            name: childKey,
                            expectedNode: children[childKey],
                            actualValue: objectValue?[childKey],
                            level: level + 1
                        )
                    }
                }
            }
        })
    }

    private func actionButtons(for element: WebViewInteractiveElement) -> some View {
        HStack(spacing: 6) {
            actionButton(symbol: "cursorarrow.click", label: "click") {
                await performAction("click") {
                    guard let webView = service.webView else { return false }
                    return try await WebViewElementInteractor(webView: webView).click(element)
                }
            }
            actionButton(symbol: "scope", label: "focus") {
                await performAction("focus") {
                    guard let webView = service.webView else { return false }
                    return try await WebViewElementInteractor(webView: webView).focus(element)
                }
            }
            actionButton(symbol: "keyboard", label: "type") {
                await performAction("type") {
                    guard let webView = service.webView else { return false }
                    return try await WebViewElementInteractor(webView: webView).type(typeText, into: element)
                }
            }
            actionButton(symbol: "return", label: "enter") {
                await performAction("enter") {
                    guard let webView = service.webView else { return false }
                    return try await WebViewElementInteractor(webView: webView).pressEnter(element)
                }
            }
            actionButton(symbol: "photo", label: "extract image") {
                await performExtractImageAction(for: element)
            }
        }
    }

    private func actionButton(symbol: String, label: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .help(label)
    }

    private func performAction(_ actionName: String, run: () async throws -> Bool) async {
        guard service.webView != nil else {
            actionStatusMessage = "\(actionName) failed (webView unavailable)"
            return
        }

        do {
            let ok = try await run()
            actionStatusMessage = ok ? "\(actionName) OK" : "\(actionName) failed"
        } catch {
            actionStatusMessage = "\(actionName) failed: \(error.localizedDescription)"
        }
    }

    private func performExtractImageAction(for element: WebViewInteractiveElement) async {
        guard let webView = service.webView else {
            actionStatusMessage = "extract image failed (webView unavailable)"
            return
        }

        do {
            let extracted = try await WebViewElementInteractor(webView: webView).extractImage(element)
            guard let extracted else {
                actionStatusMessage = "extract image failed"
                return
            }

            let image: NSImage
            if let base64 = extracted.base64 {
                guard let imageData = Data(base64Encoded: base64), let decodedImage = NSImage(data: imageData) else {
                    actionStatusMessage = "extract image failed (invalid base64)"
                    return
                }
                image = decodedImage
            } else if let x = extracted.x, let y = extracted.y, let width = extracted.width, let height = extracted.height {
                if let snapshot = try await takeSnapshot(
                    of: webView,
                    rect: CGRect(x: x, y: y, width: width, height: height)
                ) {
                    image = snapshot
                } else if let source = extracted.source, let downloaded = try await loadImageFromHTTPSource(source) {
                    image = downloaded
                } else {
                    actionStatusMessage = "extract image failed (snapshot/source unavailable)"
                    return
                }
            } else if let source = extracted.source, let downloaded = try await loadImageFromHTTPSource(source) {
                image = downloaded
            } else {
                actionStatusMessage = "extract image failed"
                return
            }

            extractedImagePreview = ExtractedImagePreview(
                image: image,
                mimeType: extracted.mimeType,
                width: extracted.width,
                height: extracted.height,
                source: extracted.source
            )
            actionStatusMessage = "extract image OK"
        } catch {
            actionStatusMessage = "extract image failed: \(error.localizedDescription)"
        }
    }

    private func takeSnapshot(of webView: WKWebView, rect: CGRect) async throws -> NSImage? {
        let sanitized = rect.standardized.integral
        guard sanitized.width > 0, sanitized.height > 0 else { return nil }

        let configuration = WKSnapshotConfiguration()
        configuration.rect = sanitized

        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private func loadImageFromHTTPSource(_ source: String) async throws -> NSImage? {
        guard let url = URL(string: source) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return NSImage(data: data)
    }

    private func reloadYAML() async {
        do {
            yamlText = try WebYAMLSelectorLoader.loadBundledYAML()
            expectedSpec = try WebYAMLExtractionRunner.makeSpec(from: yamlText)
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
            expectedSpec = try WebYAMLExtractionRunner.makeSpec(from: yamlText)
            resultJSON = try await WebYAMLExtractionRunner.run(yamlText: yamlText, in: webView)
            resultObject = parseJSONObject(from: resultJSON)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleAutoTestOnYAMLChange() {
        autoTestTask?.cancel()
        autoTestTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            guard service.state == .started, service.webView != nil else { return }
            guard !yamlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            guard (try? WebYAMLExtractionRunner.makeSpec(from: yamlText)) != nil else { return }
            await runTest()
        }
    }

    private func parseJSONObject(from text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        let object = try? JSONSerialization.jsonObject(with: data)
        return object as? [String: Any]
    }

    private func expectedType(from expectedNode: Any?) -> String {
        guard let node = expectedNode as? [String: Any] else { return "group" }
        if let type = node["type"] as? String, !type.isEmpty {
            return type.lowercased()
        }
        if expectedChildren(from: node) != nil {
            return "element"
        }
        return "text"
    }

    private func expectedChildren(from expectedNode: Any?) -> [String: Any]? {
        guard let node = expectedNode as? [String: Any] else { return nil }
        if let extract = node["extract"] as? [String: Any] { return extract }
        if let children = node["children"] as? [String: Any] { return children }
        return nil
    }

    private func valueStatus(type: String, value: Any?) -> (color: Color, text: String) {
        if let handle = WebViewInteractiveElementDetector.from(value as Any) {
            return (.green, "element handle (\(handle.id))")
        }

        switch type {
        case "elements":
            let count = (value as? [Any])?.count ?? 0
            return count > 0 ? (.green, "\(count) items") : (.red, "0 items")
        case "element":
            if let object = value as? [String: Any], !object.isEmpty { return (.green, "found") }
            if value is Bool { return ((value as? Bool == true) ? .green : .red, String(describing: value!)) }
            return (value == nil || value is NSNull) ? (.red, "null") : (.green, "found")
        case "number":
            if let number = value as? NSNumber { return (.green, "\(number)") }
            return (.red, "null")
        case "text":
            if let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let preview = text.count > 40 ? String(text.prefix(40)) + "..." : text
                return (.green, "\"\(preview)\"")
            }
            return (.red, "null")
        case "boolean", "exists":
            let boolValue = value as? Bool ?? false
            return (boolValue ? .green : .red, boolValue ? "true" : "false")
        default:
            if let boolValue = value as? Bool { return (boolValue ? .green : .red, boolValue ? "true" : "false") }
            if let array = value as? [Any] { return array.isEmpty ? (.red, "0 items") : (.green, "\(array.count) items") }
            if let dict = value as? [String: Any] { return dict.isEmpty ? (.red, "empty object") : (.green, "object") }
            if value == nil || value is NSNull { return (.red, "null") }
            return (.green, "value")
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

private struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.string = text
        textView.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}
