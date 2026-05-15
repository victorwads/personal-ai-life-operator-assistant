import SwiftUI

struct ServerLogsScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedId: MCPServerCallEntry.ID?
    @State private var query = ""
    @State private var isResending = false
    @FocusState private var listFocused: Bool
    @State private var includeGet = true
    @State private var includePost = true
    @State private var includeSuccess = true
    @State private var includeError = true

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)

            Divider()

            HSplitView {
                leftPane
                    .frame(minWidth: 360, idealWidth: 520, maxWidth: 900)

                rightPane
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Search (path, method, status)", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 520)

                Spacer()

                Text("\(filteredCalls.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    appModel.clearServerCalls()
                    selectedId = nil
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(appModel.serverCalls.isEmpty)
            }

            HStack(spacing: 8) {
                filterToggle("GET", isOn: $includeGet)
                filterToggle("POST", isOn: $includePost)
                Divider()
                    .frame(height: 18)
                filterToggle("Success", isOn: $includeSuccess)
                filterToggle("Error", isOn: $includeError)
                Spacer()
            }
        }
    }

    private var leftPane: some View {
        List(selection: $selectedId) {
            ForEach(filteredCalls) { entry in
                row(entry)
                    .tag(entry.id)
                    .onTapGesture {
                        selectedId = entry.id
                        listFocused = true
                    }
            }
        }
        .focused($listFocused)
        .onChange(of: query) { _, _ in
            if let selectedId, !filteredCalls.contains(where: { $0.id == selectedId }) {
                self.selectedId = nil
            }
        }
        .onChange(of: appModel.serverCalls.count) { _, _ in
            if let selectedId, !appModel.serverCalls.contains(where: { $0.id == selectedId }) {
                self.selectedId = nil
            }
        }
    }

    private var rightPane: some View {
        Group {
            if let selected = selectedCall {
                details(selected)
            } else {
                ContentUnavailableView(
                    "No request selected",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(appModel.serverCalls.isEmpty ? "No server calls captured yet." : "Select a call on the left to inspect request and response details.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var filteredCalls: [MCPServerCallEntry] {
        appModel.serverCalls.filter { entry in
            let method = entry.requestMethod.uppercased()
            let methodMatches =
                (method == "GET" && includeGet)
                    || (method == "POST" && includePost)
                    || (method != "GET" && method != "POST")

            let status = entry.responseStatusCode
            let statusMatches: Bool = if status == 0 {
                includeSuccess
            } else {
                ((200..<400).contains(status) && includeSuccess)
                    || (status >= 400 && includeError)
            }

            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatches: Bool
            if trimmed.isEmpty {
                searchMatches = true
            } else {
                let needle = trimmed.lowercased()
                searchMatches =
                    entry.requestPath.lowercased().contains(needle)
                        || method.lowercased().contains(needle)
                        || String(status).contains(needle)
            }

            return methodMatches && statusMatches && searchMatches
        }
        .sorted { $0.timestamp > $1.timestamp }
    }

    private var selectedCall: MCPServerCallEntry? {
        guard let selectedId else { return nil }
        return appModel.serverCalls.first(where: { $0.id == selectedId })
    }

    private func row(_ entry: MCPServerCallEntry) -> some View {
        HStack(spacing: 10) {
            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .foregroundStyle(.secondary)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 78, alignment: .leading)

            Text(entry.requestMethod)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .frame(width: 52, alignment: .leading)

            Text(entry.requestPath)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(.caption, design: .monospaced))

            Spacer()

            Text("\(entry.responseStatusCode)")
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(statusColor(entry.responseStatusCode))
                .frame(width: 40, alignment: .trailing)

            Text("\(entry.durationMilliseconds)ms")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private func filterToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func details(_ entry: MCPServerCallEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                summary(entry)

                Divider()

                Text("Request")
                    .font(.headline)

                headerTable(entry.requestHeaders)

                bodyView(entry.requestBody)

                Divider()

                Text("Response")
                    .font(.headline)

                headerTable(entry.responseHeaders)

                bodyView(entry.responseBody)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func summary(_ entry: MCPServerCallEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("\(entry.requestMethod) \(entry.requestPath)")
                    .font(.system(.headline, design: .monospaced))
                    .textSelection(.enabled)

                Spacer()

                Button {
                    guard !isResending else { return }
                    isResending = true
                    Task { @MainActor in
                        await appModel.resendServerCall(entry)
                        isResending = false
                    }
                } label: {
                    Label(isResending ? "Resending…" : "Resend", systemImage: "arrow.clockwise")
                }
                .disabled(isResending)
            }

            HStack(spacing: 10) {
                Text(entry.timestamp, format: .dateTime.year().month().day().hour().minute().second())
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))

                Text("status \(entry.responseStatusCode)")
                    .foregroundStyle(statusColor(entry.responseStatusCode))
                    .font(.system(.caption, design: .monospaced).weight(.semibold))

                Text("\(entry.durationMilliseconds)ms")
                    .foregroundStyle(.secondary)
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }

    private func headerTable(_ headers: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if headers.isEmpty {
                Text("Headers: (none)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Text("Headers")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(headers.keys.sorted(), id: \.self) { key in
                    let value = headers[key] ?? ""
                    HStack(alignment: .top, spacing: 10) {
                        Text(key)
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .frame(width: 220, alignment: .leading)
                        Text(value)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func bodyView(_ data: Data) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Body")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(prettyBody(data))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func prettyBody(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        if
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let text = String(data: pretty, encoding: .utf8)
        {
            return text
        }
        return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
    }

    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        default: .red
        }
    }
}
