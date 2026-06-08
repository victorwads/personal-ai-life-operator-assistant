import SwiftUI

struct AIResourceUsageView: View {
    let repository: any AIResourceUsageRepository

    @State private var state: UIState = .loading
    @State private var currentUse = AIResourceUsageDocument()
    @State private var sessionUse = AIResourceUsageDocument()
    @State private var pendingUnsyncedUse: AIResourceUsageDocument? = nil
    @State private var isRefreshing = false

    enum UIState: Equatable {
        case loading
        case loaded
        case empty
        case error(String)
    }

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Resource Usage",
                    subtitle: "Visual representation of accumulated token usage and active session stats."
                ) {
                    DSRefreshButton(isLoading: isRefreshing) {
                        Task { await refreshData() }
                    }
                }

                Group {
                    switch state {
                    case .loading:
                        ProgressView("Loading resource usage...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .error(let message):
                        EmptyStateView(
                            title: "Failed to Load Usage",
                            message: message,
                            systemImage: "exclamationmark.triangle",
                            actionTitle: "Retry",
                            action: {
                                Task { await loadData() }
                            }
                        )
                    case .empty:
                        EmptyStateView(
                            title: "No Usage Data Available",
                            message: "Accumulated resource usage will appear here once AI requests are made.",
                            systemImage: "waveform",
                            actionTitle: "Refresh",
                            action: {
                                Task { await refreshData() }
                            }
                        )
                    case .loaded:
                        contentView
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Usage Summary Grid
                let columns = [
                    GridItem(.adaptive(minimum: 200, maximum: .infinity), spacing: 16)
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    TokenUsageCard(
                        title: "Total Usage",
                        systemImage: "chart.bar.doc.horizontal.fill",
                        usage: currentUse.total
                    )

                    TokenUsageCard(
                        title: "Assistant Usage",
                        systemImage: "person.fill.and.arrow.left.and.arrow.right",
                        usage: currentUse.assistant
                    )

                    TokenUsageCard(
                        title: "Image Extraction Usage",
                        systemImage: "photo.fill",
                        usage: currentUse.imageExtraction
                    )
                }

                // Data Source Warning Warning Note
                HStack(alignment: .top, spacing: 8) {
                    DSBadge("Note", systemImage: "exclamationmark.triangle", style: .warning)
                    Text("Image extraction token usage is only counted when the provider returns usage data. Unreported usage is not estimated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)

                // Session & Sync Status
                DSTitledSection(
                    title: "Session & Sync Status",
                    subtitle: "Usage metrics tracked during the active application process",
                    systemImage: "clock.fill"
                ) {
                    HStack(alignment: .top, spacing: 32) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ACTIVE SESSION")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)

                            sessionUsageDetails(sessionUse.total)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let pending = pendingUnsyncedUse, pending.total.requests > 0 {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("PENDING SYNC")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.orange)

                                sessionUsageDetails(pending.total)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.trailing, 4)
        }
    }

    @ViewBuilder
    private func sessionUsageDetails(_ usage: AIResourceTokenUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Requests: \(formatTokenCount(usage.requests))")
            Text("Input Tokens: \(formatTokenCount(usage.inputTokens))")
            Text("Output Tokens: \(formatTokenCount(usage.outputTokens))")
            Text("Reasoning Tokens: \(formatTokenCount(usage.reasoningTokens))")
            Text("Cached Input: \(formatTokenCount(usage.cachedInputTokens))")
            Text("Total Tokens: \(formatTokenCount(usage.totalTokens))")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func loadData() async {
        state = .loading
        do {
            let doc = try await repository.loadCurrentUse()
            currentUse = doc
            sessionUse = repository.sessionUse
            pendingUnsyncedUse = repository.pendingUnsyncedUse

            if doc.total.requests == 0 && sessionUse.total.requests == 0 {
                state = .empty
            } else {
                state = .loaded
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func refreshData() async {
        isRefreshing = true
        do {
            let doc = try await repository.loadCurrentUse()
            currentUse = doc
            sessionUse = repository.sessionUse
            pendingUnsyncedUse = repository.pendingUnsyncedUse

            if doc.total.requests == 0 && sessionUse.total.requests == 0 {
                state = .empty
            } else {
                state = .loaded
            }
        } catch {
            state = .error(error.localizedDescription)
        }
        isRefreshing = false
    }

    private func formatTokenCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000.0
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            if let formatted = formatter.string(from: NSNumber(value: millions)) {
                return "\(formatted)M"
            }
        }

        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}

private struct TokenUsageCard: View {
    let title: String
    let systemImage: String
    let usage: AIResourceTokenUsage

    var body: some View {
        DSCard(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Requests")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTokenCount(usage.requests))
                        .fontWeight(.semibold)
                }
                Divider()
                HStack {
                    Text("Input Tokens")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTokenCount(usage.inputTokens))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Cached Input")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTokenCount(usage.cachedInputTokens))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Output Tokens")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTokenCount(usage.outputTokens))
                        .fontWeight(.semibold)
                }
                HStack {
                    Text("Reasoning Tokens")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTokenCount(usage.reasoningTokens))
                        .fontWeight(.semibold)
                }
                Divider()
                HStack {
                    Text("Total Tokens")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTokenCount(usage.totalTokens))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .font(.subheadline)
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if count >= 1_000_000 {
            let millions = Double(count) / 1_000_000.0
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            if let formatted = formatter.string(from: NSNumber(value: millions)) {
                return "\(formatted)M"
            }
        }

        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
