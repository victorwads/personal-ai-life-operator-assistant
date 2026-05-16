import SwiftUI

struct SubjectsScreen: View {
    @EnvironmentObject private var appModel: AppModel

    private enum Filter: String, CaseIterable, Identifiable {
        case active = "Active"
        case all = "All"
        case resolved = "Resolved"
        case canceled = "Canceled"

        var id: String { rawValue }
    }

    @State private var filter: Filter = .active
    @State private var entries: [SubjectEntry] = []
    @State private var errorText: String?
    @State private var isWorking = false
    @State private var pendingCancelEntry: SubjectEntry?
    @State private var cancelReason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Spacer()

                Button("Refresh") {
                    Task { await reload() }
                }
                .disabled(isWorking)
            }

            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            List(filteredEntries) { entry in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.body.weight(.semibold))

                        let summary = entry.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !summary.isEmpty {
                            Text(summary)
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                        }

                        let initialRequest = entry.initialRequest.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !initialRequest.isEmpty {
                            Text("Pedido inicial: \(initialRequest)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        if let details = entry.details, !details.isEmpty {
                            Text(details)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if !entry.eventLog.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    "Eventos:\n\(entry.eventLog.map { "• [\($0.timestamp.formatted(date: .omitted, time: .shortened))] \($0.description)" }.joined(separator: "\n"))"
                                )
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(3)
                            }
                        }

                        if !entry.nextSteps.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Follow-up:\n\(entry.nextSteps.prefix(3).map { "• \($0)" }.joined(separator: "\n"))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }

                        HStack(spacing: 10) {
                            Text(entry.status.displayName)
                                .font(.caption.monospaced())
                                .foregroundStyle(statusColor(for: entry.status))

                            Text("P\(entry.priority)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)

                            if let chatId = entry.whatsappChatId, !chatId.isEmpty {
                                Text("WA")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .help(chatId)
                            }

                            if let threadId = entry.gmailThreadId, !threadId.isEmpty {
                                Text("Gmail")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .help(threadId)
                            }

                            if let eventId = entry.calendarEventId, !eventId.isEmpty {
                                Text("Cal")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .help(eventId)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(entry.updatedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if entry.status == .active {
                        Button {
                            pendingCancelEntry = entry
                            cancelReason = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Cancel")
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .sheet(item: $pendingCancelEntry) { entry in
            VStack(alignment: .leading, spacing: 16) {
                Text("Cancel Subject")
                    .font(.title3.weight(.semibold))

                Text(entry.title)
                    .font(.headline)

                Text("Reason")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $cancelReason)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )

                HStack {
                    Spacer()

                    Button("Dismiss") {
                        pendingCancelEntry = nil
                        cancelReason = ""
                    }

                    Button("Cancel Subject") {
                        Task { await cancel(entry, reason: cancelReason) }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isWorking || cancelReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
        .task {
            guard !PreviewSupport.isRunningForPreviews else { return }
            await reload()
        }
    }

    private var filteredEntries: [SubjectEntry] {
        switch filter {
        case .active:
            return entries.filter { $0.status == .active }
        case .resolved:
            return entries.filter { $0.status == .resolved }
        case .canceled:
            return entries.filter { $0.status == .canceled }
        case .all:
            return entries
        }
    }

    private func reload() async {
        entries = await appModel.subjectsRepository.listAll()
    }

    private func statusColor(for status: SubjectStatus) -> Color {
        switch status {
        case .active:
            return .green
        case .resolved:
            return .blue
        case .canceled:
            return .orange
        }
    }

    private func cancel(_ entry: SubjectEntry, reason: String) async {
        errorText = nil
        isWorking = true
        defer { isWorking = false }

        do {
            _ = try await appModel.subjectsRepository.cancel(id: entry.id, reason: reason)
            pendingCancelEntry = nil
            cancelReason = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    SubjectsScreen()
        .environmentObject(AppModel.preview)
        .frame(width: 980, height: 680)
}
