import SwiftUI

struct SentMessagesScreen: View {
    let feature: SentMessagesFeature

    @State private var sentMessages: [SentMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        FeatureScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                DSFeatureHeader(
                    title: "Sent Messages",
                    subtitle: "Cross-channel audit history for outbound assistant communication."
                ) {
                    DSRefreshButton(isLoading: isLoading) {
                        Task { await loadSentMessages() }
                    }
                }

                if isLoading {
                    ProgressView("Loading sent messages...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let errorMessage {
                    EmptyStateView(
                        title: "Could not load sent messages",
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle",
                        actionTitle: "Retry",
                        action: {
                            Task { await loadSentMessages() }
                        }
                    )
                } else if sentMessages.isEmpty {
                    EmptyStateView(
                        title: "No sent messages yet",
                        message: "Outbound sends and send attempts will appear here.",
                        systemImage: "paperplane"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(sentMessages, id: \.id) { sentMessage in
                                SentMessageRowView(sentMessage: sentMessage)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadSentMessages()
        }
    }

    @MainActor
    private func loadSentMessages() async {
        isLoading = true
        errorMessage = nil

        do {
            sentMessages = try await feature.repository.listAll(limit: 100)
        } catch {
            errorMessage = error.localizedDescription
            sentMessages = []
        }

        isLoading = false
    }
}
