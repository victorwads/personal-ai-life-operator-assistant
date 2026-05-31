import SwiftUI

struct SensitiveDataScreen: View {
    let feature: SensitiveDataFeature

    @State private var items: [SensitiveDataItem] = []
    @State private var usageEntries: [SensitiveDataUsage] = []
    @State private var areValuesVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Sensitive Data",
                    subtitle: "Protected profile-scoped values, safe metadata, and access audit history."
                ) {
                    HStack(spacing: 12) {
                        Button {
                            areValuesVisible.toggle()
                        } label: {
                            Label(
                                areValuesVisible ? "Hide Values" : "Show Values",
                                systemImage: areValuesVisible ? "eye.slash" : "eye"
                            )
                        }

                        DSRefreshButton(isLoading: isLoading) {
                            Task { await loadData() }
                        }
                    }
                }

                content
            }
        }
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && items.isEmpty && usageEntries.isEmpty {
            ProgressView("Loading sensitive data...")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let errorMessage {
            EmptyStateView(
                title: "Could not load sensitive data",
                message: errorMessage,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Retry",
                action: {
                    Task { await loadData() }
                }
            )
        } else if items.isEmpty && usageEntries.isEmpty {
            EmptyStateView(
                title: "No sensitive data yet",
                message: "Protected values and their audit history will appear here after the MCP tools are used.",
                systemImage: "lock.shield"
            )
        } else {
            GeometryReader { geometry in
                ScrollView {
                    if geometry.size.width >= 920 {
                        HStack(alignment: .top, spacing: 20) {
                            safeMetadataSection
                                .frame(
                                    width: max((geometry.size.width - 20) * 0.6, 0),
                                    alignment: .topLeading
                                )

                            usageSection
                                .frame(
                                    width: max((geometry.size.width - 20) * 0.4, 0),
                                    alignment: .topLeading
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 24)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            safeMetadataSection
                            usageSection
                        }
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .refreshable {
                await loadData()
            }
        }
    }

    private var safeMetadataSection: some View {
        DSTitledSection(
            title: "Stored Items",
            subtitle: "Values stay masked here by default. MCP list and search still expose metadata only.",
            systemImage: "lock.doc"
        ) {
            if items.isEmpty {
                Text("No active sensitive data items.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items, id: \.key) { item in
                        DSListCardRow(
                            title: item.key,
                            subtitle: item.issueId.map { "Issue: \($0)" } ?? "No issue linked",
                            description: valueDescription(for: item),
                            badges: {
                                HStack(spacing: 8) {
                                    DSBadge("Kind", secondaryText: item.kind.rawValue, style: .info)
                                    DSBadge("Value", secondaryText: valueStatus(for: item))
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var usageSection: some View {
        DSTitledSection(
            title: "Recent Usage",
            subtitle: "Every access and mutation is recorded, including list and search actions.",
            systemImage: "clock.arrow.circlepath"
        ) {
            if usageEntries.isEmpty {
                Text("No audit entries yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(usageEntries, id: \.id) { usage in
                        DSListCardRow(
                            title: displayKey(for: usage),
                            subtitle: "Issue: \(usage.issueId)",
                            description: usage.reason,
                            badges: {
                                HStack(spacing: 8) {
                                    DSBadge("Action", secondaryText: usage.action.rawValue, style: badgeStyle(for: usage.action))
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func badgeStyle(for action: SensitiveDataUsageAction) -> DSBadge.Style {
        switch action {
        case .get, .list, .search:
            return .info
        case .save, .update:
            return .warning
        case .delete:
            return .danger
        }
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

    private func valueDescription(for item: SensitiveDataItem) -> String {
        guard let value = item.value else {
            return "No value stored."
        }

        guard !value.isEmpty else {
            return "Value is empty."
        }

        return areValuesVisible ? value : maskedValue(for: value)
    }

    private func valueStatus(for item: SensitiveDataItem) -> String {
        guard let value = item.value else {
            return "Missing"
        }

        return value.isEmpty ? "Empty" : (areValuesVisible ? "Visible" : "Hidden")
    }

    private func maskedValue(for value: String) -> String {
        let maskedCount = min(max(value.count, 8), 24)
        return String(repeating: "•", count: maskedCount)
    }

    @MainActor
    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let itemsTask = feature.repositories.data.list(kinds: nil, includeDeleted: false)
            async let usageTask = feature.repositories.usage.listRecentUsage()
            items = try await itemsTask
            usageEntries = try await usageTask
        } catch {
            items = []
            usageEntries = []
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
