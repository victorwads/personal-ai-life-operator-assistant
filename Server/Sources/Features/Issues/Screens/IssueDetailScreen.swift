// TODO: Split this screen into smaller focused pieces before adding more behavior.
// Current file mixes layout, async loading, related-section rendering, and domain-to-UI
// formatting helpers. Suggested split:
// - IssueDetailViewModel for loading/state
// - IssueOverviewSection / IssueTimelineSection / IssueRelatedActivitySections
// - IssueDetailDisplaySupport for badge styles, labels, date/text formatting
import SwiftUI

struct IssueDetailScreen: View {
    let issueId: String
    let issuesFeature: IssuesFeature
    let relatedDataProvider: IssueRelatedDataProviding?

    @State private var issue: Issue?
    @State private var timelineItems: [IssueTimelineItem] = []
    @State private var sensitiveDataUsage: [SensitiveDataUsage] = []
    @State private var sentMessages: [SentMessage] = []
    @State private var clientInteractionRequests: [ClientInteractionRequest] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 20) {
                DSFeatureHeader(
                    title: issue?.title ?? "Issue Detail",
                    subtitle: issue.map { $0.id ?? issueId } ?? issueId
                ) {
                    HStack(spacing: 8) {
                        if let issue {
                            DSBadge(
                                "Status",
                                secondaryText: issue.status.rawValue,
                                style: statusBadgeStyle(for: issue.status)
                            )
                            DSBadge(
                                "Priority",
                                secondaryText: priorityText(for: issue.priority),
                                style: priorityBadgeStyle(for: issue.priority)
                            )
                        }

                        DSRefreshButton(isLoading: isLoading) {
                            Task { await loadDetail() }
                        }
                    }
                }

                content
            }
        }
        .task {
            await loadDetail()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && issue == nil {
            ProgressView("Loading issue details...")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let errorMessage {
            EmptyStateView(
                title: "Could not load issue detail",
                message: errorMessage,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Retry",
                action: {
                    Task { await loadDetail() }
                }
            )
        } else if let issue {
            GeometryReader { geometry in
                ScrollView {
                    if geometry.size.width >= 1080 {
                        HStack(alignment: .top, spacing: 20) {
                            primaryColumn(issue: issue)
                                .frame(
                                    width: max((geometry.size.width - 20) * 0.58, 0),
                                    alignment: .topLeading
                                )

                            relatedColumn
                                .frame(
                                    width: max((geometry.size.width - 20) * 0.42, 0),
                                    alignment: .topLeading
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 24)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            primaryColumn(issue: issue)
                            relatedColumn
                        }
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            EmptyStateView(
                title: "Issue not found",
                message: "This issue is not available in the local profile cache.",
                systemImage: "questionmark.circle"
            )
        }
    }

    private func primaryColumn(issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            overviewSection(issue: issue)
            textSection(
                title: "Description",
                subtitle: "Operational summary for this issue.",
                systemImage: "doc.text",
                text: issue.description
            )
            textSection(
                title: "Initial Request",
                subtitle: "What triggered the issue.",
                systemImage: "sparkle.magnifyingglass",
                text: issue.initialRequest
            )
            textSection(
                title: "Resolution Condition",
                subtitle: "What must be true for the issue to be closed.",
                systemImage: "checkmark.seal",
                text: issue.resolutionCondition
            )
            timelineSection
        }
    }

    private var relatedColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            sensitiveDataSection
            sentMessagesSection
            clientVoiceSection
            referencesSection
        }
    }

    private func overviewSection(issue: Issue) -> some View {
        DSTitledSection(
            title: "Overview",
            subtitle: "Stored issue fields and lifecycle state.",
            systemImage: "info.circle"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    DSBadge("Status", secondaryText: issue.status.rawValue, style: statusBadgeStyle(for: issue.status))
                    DSBadge("Priority", secondaryText: priorityText(for: issue.priority), style: priorityBadgeStyle(for: issue.priority))
                    DSBadge("Finished", secondaryText: issue.finished ? "Yes" : "No", style: issue.finished ? .success : .neutral)
                }

                VStack(alignment: .leading, spacing: 12) {
                    overviewRow("Issue ID", issue.id ?? issueId)
                    overviewRow("Status", issue.status.rawValue)
                    overviewRow("Priority", priorityText(for: issue.priority))
                    overviewRow("Finished", issue.finished ? "Yes" : "No")
                    overviewRow("Suspend Until", formattedDate(issue.suspendUntil))
                }
            }
        }
    }

    private func textSection(
        title: String,
        subtitle: String,
        systemImage: String,
        text: String
    ) -> some View {
        DSTitledSection(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        ) {
            Text(nonEmpty(text, fallback: "No value recorded."))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var timelineSection: some View {
        DSTitledSection(
            title: "Timeline",
            subtitle: "Lifecycle and update records linked to this issue.",
            systemImage: "clock.arrow.circlepath"
        ) {
            if timelineItems.isEmpty {
                emptySectionText("No timeline items recorded yet.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(timelineItems, id: \.id) { item in
                        DSListCardRow(
                            title: formattedTimelineTitle(item.kind),
                            subtitle: item.id ?? "No item id",
                            description: item.description
                        ) {
                            DSBadge("Kind", secondaryText: item.kind, style: .info)
                        }
                    }
                }
            }
        }
    }

    private var sensitiveDataSection: some View {
        DSTitledSection(
            title: "Sensitive Data Usage",
            subtitle: "Audit metadata only. Protected values are never shown here.",
            systemImage: "lock.shield"
        ) {
            if sensitiveDataUsage.isEmpty {
                emptySectionText("No sensitive data usage is linked to this issue.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sensitiveDataUsage, id: \.id) { usage in
                        DSListCardRow(
                            title: displayKey(for: usage),
                            subtitle: "Reason: \(usage.reason)",
                            description: "Usage id: \(usage.id ?? "No id")"
                        ) {
                            DSBadge(
                                "Action",
                                secondaryText: usage.action.rawValue,
                                style: usageBadgeStyle(for: usage.action)
                            )
                        }
                    }
                }
            }
        }
    }

    private var sentMessagesSection: some View {
        DSTitledSection(
            title: "Sent Messages",
            subtitle: "Outbound communication audited under this issue.",
            systemImage: "paperplane"
        ) {
            if sentMessages.isEmpty {
                emptySectionText("No sent messages are linked to this issue.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sentMessages, id: \.id) { sentMessage in
                        SentMessageRowView(sentMessage: sentMessage)
                    }
                }
            }
        }
    }

    private var clientVoiceSection: some View {
        DSTitledSection(
            title: "Client Voice",
            subtitle: "Auditable client interaction requests linked to this issue.",
            systemImage: "waveform"
        ) {
            if clientInteractionRequests.isEmpty {
                emptySectionText("No client voice records are available for this issue yet.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(clientInteractionRequests, id: \.id) { request in
                        DSListCardRow(
                            title: clientVoiceTitle(for: request.kind),
                            subtitle: request.id ?? "No record id",
                            description: clientVoiceDescription(for: request)
                        ) {
                            HStack(spacing: 8) {
                                DSBadge("Kind", secondaryText: request.kind.rawValue, style: .info)
                                DSBadge(
                                    "Status",
                                    secondaryText: request.status.rawValue,
                                    style: clientInteractionStatusBadgeStyle(for: request.status)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var referencesSection: some View {
        DSTitledSection(
            title: "References",
            subtitle: "Chat and thread references derived from related issue activity when available.",
            systemImage: "link"
        ) {
            let chatReferences = sentMessages

            if chatReferences.isEmpty {
                emptySectionText("No chat or thread references are available yet.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(chatReferences, id: \.id) { sentMessage in
                        DSListCardRow(
                            title: sentMessage.chatTitle ?? sentMessage.chatId,
                            subtitle: "Chat ID: \(sentMessage.chatId)",
                            description: providerReferenceText(for: sentMessage),
                            systemImage: "message"
                        ) {
                            DSBadge("Source", secondaryText: "Sent Message", style: .neutral)
                        }
                    }
                }
            }
        }
    }

    private func emptySectionText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func loadDetail() async {
        isLoading = true
        errorMessage = nil

        do {
            async let issueTask = issuesFeature.issue(id: issueId)
            async let timelineTask = issuesFeature.listTimelineItems(issueId: issueId)
            async let sensitiveDataTask = loadSensitiveDataUsage()
            async let sentMessagesTask = loadSentMessages()
            async let clientVoiceTask = loadClientInteractionRequests()

            issue = try await issueTask
            timelineItems = try await timelineTask
            sensitiveDataUsage = try await sensitiveDataTask
            sentMessages = try await sentMessagesTask
            clientInteractionRequests = try await clientVoiceTask
        } catch {
            issue = nil
            timelineItems = []
            sensitiveDataUsage = []
            sentMessages = []
            clientInteractionRequests = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func overviewRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .textSelection(.enabled)
        }
    }

    private func loadSensitiveDataUsage() async throws -> [SensitiveDataUsage] {
        guard let relatedDataProvider else {
            return []
        }

        return try await relatedDataProvider.listSensitiveDataUsageByIssueId(issueId)
    }

    private func loadSentMessages() async throws -> [SentMessage] {
        guard let relatedDataProvider else {
            return []
        }

        return try await relatedDataProvider.listSentMessagesByIssueId(issueId)
    }

    private func loadClientInteractionRequests() async throws -> [ClientInteractionRequest] {
        guard let relatedDataProvider else {
            return []
        }

        return try await relatedDataProvider.listClientInteractionRequestsByIssueId(issueId)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "Not scheduled"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : value
    }

    private func formattedTimelineTitle(_ kind: String) -> String {
        let words = kind
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return words.isEmpty ? "Timeline Item" : words.localizedCapitalized
    }

    private func displayKey(for usage: SensitiveDataUsage) -> String {
        if usage.key == SensitiveDataMCPToolSupport.listAuditKey {
            return "Collection List"
        }

        let searchPrefix = "__search__:"
        if usage.key.hasPrefix(searchPrefix) {
            return "Search: \(usage.key.dropFirst(searchPrefix.count))"
        }

        return usage.key
    }

    private func providerReferenceText(for sentMessage: SentMessage) -> String {
        if !sentMessage.chatMessageIds.isEmpty {
            return "Chat Message IDs: \(sentMessage.chatMessageIds.joined(separator: ", "))"
        }

        if let firstMessage = sentMessage.messages.first, !firstMessage.isEmpty {
            return firstMessage
        }

        return "No thread reference recorded."
    }

    private func clientVoiceTitle(for kind: ClientInteractionRequest.Kind) -> String {
        switch kind {
        case .ask:
            return "Ask Request"
        case .speak:
            return "Speak Request"
        }
    }

    private func clientVoiceDescription(for request: ClientInteractionRequest) -> String {
        var lines: [String] = [request.promptText]

        if let responseText = request.responseText?.trimmingCharacters(in: .whitespacesAndNewlines), !responseText.isEmpty {
            lines.append("Response: \(responseText)")
        }

        return lines.joined(separator: "\n")
    }

    private func priorityText(for priority: IssuePriority) -> String {
        switch priority {
        case .veryLow:
            return "1 Very Low"
        case .low:
            return "2 Low"
        case .medium:
            return "3 Medium"
        case .high:
            return "4 High"
        case .urgent:
            return "5 Urgent"
        }
    }

    private func statusBadgeStyle(for status: IssueStatus) -> DSBadge.Style {
        switch status {
        case .pending:
            return .info
        case .suspended:
            return .warning
        case .resolved:
            return .success
        case .cancelled:
            return .danger
        }
    }

    private func priorityBadgeStyle(for priority: IssuePriority) -> DSBadge.Style {
        switch priority.rawValue {
        case 1, 2:
            return .neutral
        case 3:
            return .info
        case 4:
            return .warning
        default:
            return .danger
        }
    }

    private func usageBadgeStyle(for action: SensitiveDataUsageAction) -> DSBadge.Style {
        switch action {
        case .get, .list, .search:
            return .info
        case .save, .update:
            return .warning
        case .delete:
            return .danger
        }
    }

    private func clientInteractionStatusBadgeStyle(for status: ClientInteractionRequest.Status) -> DSBadge.Style {
        switch status {
        case .initialized:
            return .info
        case .waitingAgent:
            return .warning
        case .completed:
            return .success
        case .cancelled:
            return .danger
        }
    }
}
