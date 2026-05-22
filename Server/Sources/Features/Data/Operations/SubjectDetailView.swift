import SwiftUI

struct SubjectDetailView: View {
    let subject: SubjectEntry?
    let relatedSensitiveAudits: [SensitiveDataAuditEntry]
    let isLoading: Bool
    let errorText: String?
    let onClose: (() -> Void)?

    init(
        subject: SubjectEntry?,
        relatedSensitiveAudits: [SensitiveDataAuditEntry],
        isLoading: Bool,
        errorText: String?,
        onClose: (() -> Void)? = nil
    ) {
        self.subject = subject
        self.relatedSensitiveAudits = relatedSensitiveAudits
        self.isLoading = isLoading
        self.errorText = errorText
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView()
                        .padding(.vertical, 8)
                }

                if let errorText {
                    Text(errorText)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let subject {
                    header(subject)
                    infoCards(subject)
                    eventTimeline(subject)
                    sensitiveAuditSection
                } else {
                    ContentUnavailableView(
                        "Select a subject",
                        systemImage: "checklist",
                        description: Text("Select a subject to inspect the full details and related sensitive-data audits.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func header(_ subject: SubjectEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.title)
                        .font(.title2.weight(.semibold))

                    Text(subject.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    if let onClose {
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Close")
                    }

                    Text(subject.status.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor(for: subject.status).opacity(0.14))
                        .clipShape(Capsule())

                    Text(subject.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if subject.status != .active, let terminalReason = subject.terminalReason {
                Text("Terminal reason: \(terminalReason)")
                    .font(.callout)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoCards(_ subject: SubjectEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subject Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                DetailRow(title: "Initial request", value: subject.initialRequest)

                if let details = subject.details, !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DetailRow(title: "Details", value: details)
                }

                DetailRow(title: "Priority", value: "P\(subject.priority)")

                if !subject.participants.isEmpty {
                    DetailRow(title: "Participants", value: subject.participants.joined(separator: ", "))
                }

                if !subject.nextSteps.isEmpty {
                    DetailRow(title: "Next steps", value: subject.nextSteps.map { "• \($0)" }.joined(separator: "\n"))
                }

                HStack(spacing: 8) {
                    chip(label: "WA \(subject.whatsappChatId ?? "none")")
                    chip(label: "After \(subject.whatsappAfterMessageId ?? "none")")
                    chip(label: "Gmail \(subject.gmailThreadId ?? "none")")
                    chip(label: "Cal \(subject.calendarEventId ?? "none")")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func eventTimeline(_ subject: SubjectEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(subject.eventLog.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let source = event.source {
                                Text(source)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(event.description)
                            .font(.callout)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var sensitiveAuditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sensitive Data")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                if relatedSensitiveAudits.isEmpty {
                    Text("No sensitive-data audits linked to this subject yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(relatedSensitiveAudits) { audit in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(audit.action.rawValue.capitalized)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Text(audit.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(audit.reason)
                                .font(.callout)

                            HStack(spacing: 8) {
                                Text("subject: \(audit.subjectId)")
                                if let key = audit.key {
                                    Text("key: \(key)")
                                } else if let query = audit.query {
                                    Text("query: \(query)")
                                }
                                if let matchedCount = audit.matchedCount {
                                    Text("matches: \(matchedCount)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(16)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
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

    private func chip(label: String) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
