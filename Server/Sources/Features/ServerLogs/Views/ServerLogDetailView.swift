import SwiftUI

struct ServerLogDetailView: View {
    let entry: ServerLogEntry
    let toolIcon: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: entry.title,
                    subtitle: entry.summary
                ) {
                    if let toolName = entry.toolName {
                        DSBadge(
                            toolName,
                            secondaryText: entry.toolCallId,
                            systemImage: toolIcon ?? "hammer",
                            style: .neutral
                        )
                    }
                }

                DSTitledSection(
                    title: "Overview",
                    subtitle: "Structured metadata for the selected log entry.",
                    systemImage: "tablecells"
                ) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        detailRow("Timestamp", value: timestampText)
                        detailRow("Kind", value: entry.kind.rawValue)
                        detailRow("Severity", value: entry.severity.rawValue)
                        detailRow("Result", value: entry.successText)
                        detailRow("Run ID", value: entry.runId ?? "-")
                        detailRow("Session ID", value: entry.sessionId ?? "-")
                        detailRow("Cycle", value: entry.cycleNumber.map(String.init) ?? "-")
                        detailRow("Duration", value: entry.durationText)
                    }
                }

                if let previewText = previewText {
                    DSTitledSection(
                        title: "Preview",
                        subtitle: "Final aggregated payload preview for the selected entry.",
                        systemImage: "doc.text.magnifyingglass"
                    ) {
                        DSCodeBlock(previewText)
                            .frame(minHeight: 120, maxHeight: 300)
                    }
                }

                DSTitledSection(
                    title: "Inspect",
                    subtitle: "Open structured payloads with the shared debug inspector.",
                    systemImage: "curlybraces"
                ) {
                    if debugItems.isEmpty {
                        Text("This log entry does not contain additional payloads.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 10) {
                            Text("Inspect input, output, error, and metadata without rendering them in every row.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            DSDebugObjectsInspector(
                                title: "Server Log Details",
                                items: debugItems
                            )

                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.trailing, 8)
        }
    }

    private var timestampText: String {
        entry.createdAt.formatted(
            .dateTime.year().month().day().hour().minute().second().secondFraction(.fractional(3))
        )
    }

    private var previewText: String? {
        switch entry.kind {
        case .reasoningCompleted:
            return entry.outputPayload
        case .assistantOutputCompleted:
            return entry.outputPayload
        default:
            return nil
        }
    }

    private var debugItems: [DebugObjectItem] {
        var items: [DebugObjectItem] = [
            DebugObjectItem(title: "Summary", value: entry.summary)
        ]

        if let inputPayload = entry.inputPayload {
            items.append(DebugObjectItem(title: "Input Payload", value: inputPayload))
        }
        if let outputPayload = entry.outputPayload {
            items.append(DebugObjectItem(title: "Output Payload", value: outputPayload))
        }
        if let errorPayload = entry.errorPayload {
            items.append(DebugObjectItem(title: "Error Payload", value: errorPayload))
        }
        if let metadataPayload = entry.metadataPayload {
            items.append(DebugObjectItem(title: "Metadata Payload", value: metadataPayload))
        }

        return items
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
        }
    }
}

private extension ServerLogEntry {
    var successText: String {
        guard let success else { return "-" }
        return success ? "Success" : "Failed"
    }
}
