import SwiftUI

struct MemoriesScreen: View {
    let feature: MemoriesFeature

    @State private var memories: [Memory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        FeatureScreenContainer(
            title: "Memories",
            subtitle: "Permanent assistant context saved for this profile."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()

                    Button {
                        loadMemories()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }

                content
            }
        }
        .task {
            await refreshMemories()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && memories.isEmpty {
            loadingState
        } else if let errorMessage {
            EmptyStateView(
                title: "Could not load memories",
                message: errorMessage,
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again",
                action: loadMemories
            )
        } else if memories.isEmpty {
            EmptyStateView(
                title: "No memories yet",
                message: "Saved assistant memories will appear here after they are created through MCP tools.",
                systemImage: "brain.head.profile"
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(memories, id: \.key) { memory in
                        KeyValueCardView(
                            title: memory.key,
                            key: "Value",
                            value: memory.value
                        )
                    }
                }
                .padding(.bottom, 24)
            }
            .refreshable {
                await refreshMemories()
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading memories...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func loadMemories() {
        Task {
            await refreshMemories()
        }
    }

    private func refreshMemories() async {
        isLoading = true
        errorMessage = nil

        do {
            memories = try await feature.repository.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
