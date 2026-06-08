import SwiftUI

struct ServerLogsTableView: View {
    @ObservedObject var viewModel: ServerLogsScreenViewModel

    var body: some View {
        Table(viewModel.entries, selection: $viewModel.selectedEntryID) {
            TableColumn("Time") { entry in
                Text(entry.createdAt, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                    .font(.caption.monospacedDigit())
            }
            .width(min: 110, ideal: 130, max: 150)

            TableColumn("") { entry in
                Image(systemName: entry.severity.systemImage)
                    .foregroundStyle(entry.severity.color)
                    .frame(maxWidth: .infinity)
            }
            .width(28)

            TableColumn("Kind") { entry in
                Text(entry.kind.displayName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 160)

            TableColumn("Message") { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(entry.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TableColumn("Tool") { entry in
                HStack(spacing: 6) {
                    if let icon = viewModel.toolIcon(for: entry.toolName) {
                        Image(systemName: icon)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.toolName ?? "-")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .width(min: 120, ideal: 160)

            TableColumn("Duration") { entry in
                Text(entry.durationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(entry.durationMilliseconds == nil ? .secondary : .primary)
            }
            .width(min: 70, ideal: 90)

            TableColumn("Result") { entry in
                Text(entry.resultText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.resultColor)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 100)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.caption)
    }
}

extension ServerLogKind {
    var displayName: String {
        switch self {
        case .sessionStarted:
            return "Session Started"
        case .promptProcessingCompleted:
            return "Prompt Processed"
        case .reasoningCompleted:
            return "Reasoning"
        case .assistantOutputCompleted:
            return "Output"
        case .toolCallCompleted:
            return "Tool Call"
        case .sessionCompleted:
            return "Session Completed"
        case .sessionFailed:
            return "Session Failed"
        case .imageExtractionCompleted:
            return "Image Extraction"
        }
    }
}

extension ServerLogsScreenViewModel.ResultFilter {
    var displayName: String {
        switch self {
        case .all:
            return "All Results"
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        }
    }
}

private extension ServerLogSeverity {
    var systemImage: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

extension ServerLogEntry {
    var durationText: String {
        guard let durationMilliseconds else { return "-" }
        if durationMilliseconds >= 1_000 {
            return String(format: "%.2fs", durationMilliseconds / 1_000)
        }
        return String(format: "%.0fms", durationMilliseconds)
    }

    var resultText: String {
        if let success {
            return success ? "Success" : "Failed"
        }

        switch severity {
        case .success:
            return "Success"
        case .error:
            return "Error"
        case .warning:
            return "Warning"
        case .info:
            return "Info"
        }
    }

    var resultColor: Color {
        if let success {
            return success ? .green : .red
        }

        switch severity {
        case .info:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
