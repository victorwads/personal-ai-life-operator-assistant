import Foundation
import SwiftUI

struct SharedUIPreviews: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerPreview
                buttonsPreview
                badgesPreview
                runtimeStatusBadgesPreview
                titledSectionsPreview
                cardsPreview
                messageBubblesPreview
                listRowsPreview
                codeBlocksPreview
                debugInspectorsPreview
                formFieldsPreview
                statesPreview
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
    }

    private var headerPreview: some View {
        previewSection("Headers") {
            DSFeatureHeader(
                title: "Memories",
                subtitle: "Permanent assistant context saved for this profile.",
                systemImage: "brain.head.profile"
            ) {
                DSRefreshButton(action: {})
            }
            .previewBounds()
        }
    }

    private var runtimeStatusBadgesPreview: some View {
        previewSection("Runtime Status Badges") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    DSRuntimeStatusBadge(
                        title: "MCP Server",
                        secondaryText: "Port 8080",
                        state: .running,
                        trailingSystemImage: "stop.fill",
                        trailingActionLabel: "Stop MCP Server",
                        trailingAction: {}
                    )

                    DSRuntimeStatusBadge(
                        title: "Crawling",
                        secondaryText: "Stopped",
                        state: .stopped,
                        trailingSystemImage: "play.fill",
                        trailingActionLabel: "Start Crawling",
                        trailingAction: {}
                    )
                }

                HStack(spacing: 8) {
                    DSRuntimeStatusBadge(title: "AI Connection", secondaryText: "Starting", state: .starting)
                    DSRuntimeStatusBadge(title: "WebView", secondaryText: "Failed", state: .failed)
                    DSRuntimeStatusBadge(title: "Runtime", state: .idle)
                }
            }
            .previewBounds()
        }
    }

    private var buttonsPreview: some View {
        previewSection("Buttons") {
            HStack(spacing: 12) {
                DSRefreshButton(action: {})
                DSRefreshButton(isLoading: true, action: {})
            }
            .previewBounds()
        }
    }

    private var badgesPreview: some View {
        previewSection("Badges") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    DSBadge("Neutral")
                    DSBadge("Info", systemImage: "info.circle", style: .info)
                    DSBadge("Success", systemImage: "checkmark.circle", style: .success)
                    DSBadge("Warning", systemImage: "exclamationmark.triangle", style: .warning)
                    DSBadge("Danger", systemImage: "xmark.octagon", style: .danger)
                }

                DSBadge("Status", secondaryText: "Waiting", systemImage: "clock", style: .neutral)
            }
            .previewBounds()
        }
    }

    private var titledSectionsPreview: some View {
        previewSection("Titled Sections") {
            DSTitledSection(
                title: "Execution Result",
                subtitle: "Titles stay outside the content bubble for section-level context.",
                systemImage: "terminal",
                prominence: .emphasized
            ) {
                Button("Retry") {}
                    .buttonStyle(.bordered)
            } content: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Use titled sections for settings groups, metadata panes, and other reusable content blocks.")
                        .foregroundStyle(.secondary)

                    DSCodeBlock(
                        """
                        {
                          "status": "ok",
                          "duration_ms": 142
                        }
                        """
                    )
                    .frame(height: 84)
                }
            }
            .previewBounds()
        }
    }

    private var cardsPreview: some View {
        previewSection("Cards") {
            VStack(alignment: .leading, spacing: 12) {
                DSCard(title: "Normal Card") {
                    Text("Reusable section cards keep feature screens visually consistent.")
                        .foregroundStyle(.secondary)
                }

                DSCard(
                    title: "Emphasized Card",
                    systemImage: "hammer",
                    prominence: .emphasized
                ) {
                    Text("Use emphasized cards sparingly for primary metadata or screen-level context.")
                        .foregroundStyle(.secondary)
                }
            }
            .previewBounds()
        }
    }

    private var messageBubblesPreview: some View {
        previewSection("Message Bubbles") {
            VStack(alignment: .leading, spacing: 12) {
                DSMessageBubbleRow(
                    alignment: .leading,
                    title: "Client",
                    subtitle: "10:42 AM"
                ) {
                    Text("Could you send the latest issue summary when you get a chance?")
                } footer: {
                    Text("Received")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                DSMessageBubbleRow(
                    alignment: .trailing,
                    title: "Assistant",
                    subtitle: "10:43 AM"
                ) {
                    Text("Absolutely. I can send the summary and flag anything still blocked.")
                        .foregroundStyle(.white)
                } footer: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Sent")
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.82))
                }

                DSMessageBubbleRow(
                    alignment: .leading,
                    title: "Client Voice",
                    subtitle: "Input controls also fit here"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This row supports arbitrary content, not just plain text.")
                        Toggle("Include transcript", isOn: .constant(true))
                    }
                }
            }
            .previewBounds()
        }
    }

    private var listRowsPreview: some View {
        previewSection("List Rows") {
            DSListCardRow(
                title: "Unread client message",
                subtitle: "Needs response",
                description: "A shared list row keeps feature indexes consistent without baking issue or memory-specific logic into Shared/UI.",
                systemImage: "message"
            ) {
                HStack(spacing: 6) {
                    DSBadge("Urgent", style: .warning)
                    DSBadge("Open", style: .info)
                }
            } trailing: {
                Button("Open") {}
                    .buttonStyle(.bordered)
            }
            .previewBounds()
        }
    }

    private var codeBlocksPreview: some View {
        previewSection("Code Blocks") {
            DSCodeBlock(
                """
                # Client memories

                ## key: client_language
                pt-BR

                ---

                ## key: client_identity
                Victor
                """
            )
            .frame(height: 96)
            .previewBounds()
        }
    }

    private var debugInspectorsPreview: some View {
        struct SampleValue: Codable {
            let id: UUID
            let name: String
            let createdAt: Date
            let tags: [String]
        }

        return previewSection("Debug Inspectors") {
            HStack(spacing: 12) {
                Text("Open JSON popover")
                    .foregroundStyle(.secondary)

                DSDebugObjectsInspector(
                    title: "Sample Debug Objects",
                    items: [
                        DebugObjectItem(
                            title: "Model",
                            value: SampleValue(
                                id: UUID(),
                                name: "Example",
                                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                                tags: ["debug", "shared-ui"]
                            )
                        ),
                        DebugObjectItem(
                            title: "Raw Response",
                            value: """
                            {
                              "id": "resp_123",
                              "message": "Keep this raw formatting exactly as-is."
                            }
                            """
                        )
                    ]
                )
            }
            .previewBounds()
        }
    }

    private var formFieldsPreview: some View {
        previewSection("Form Fields") {
            VStack(alignment: .leading, spacing: 16) {
                DSSettingsTextField(
                    title: "Message Header",
                    prompt: "Optional first message",
                    helperText: "If filled, this is sent as a separate first message before the main batch.",
                    text: .constant("Oi! Aqui vai um resumo antes da mensagem principal.")
                )

                DSSettingsTextField(
                    title: "Message Prefix",
                    prompt: "Optional text before each message",
                    helperText: "Added to the start of every main message in the batch, not just the first one.",
                    text: .constant("[Assistente] ")
                )
            }
            .previewBounds()
        }
    }

    private var statesPreview: some View {
        previewSection("States And Containers") {
            VStack(alignment: .leading, spacing: 12) {
                FeatureScreenContainer(
                    title: "FeatureScreenContainer Title",
                    subtitle: "Optional subtitle text gives context for the feature screen."
                ) {
                    KeyValueCardView(
                        title: "Content Closure Example",
                        rows: [
                            KeyValueCardRow("Content Row", "Rendered inside the container"),
                            KeyValueCardRow("Layout", "Top-leading with shared padding")
                        ]
                    )
                }

                EmptyStateView(
                    title: "EmptyStateView Title",
                    message: "Message text explains what is missing and what can happen next.",
                    systemImage: "tray",
                    actionTitle: "Action Title",
                    action: {}
                )

                KeyValueCardView(
                    title: "KeyValueCardView Title",
                    rows: [
                        KeyValueCardRow("First Key", "Primary value"),
                        KeyValueCardRow("Second Key", "Secondary value"),
                        KeyValueCardRow("Third Key", "Additional value")
                    ]
                )

                KeyValueCardView(
                    key: "Single Key",
                    value: "Single value"
                )
            }
            .previewBounds()
        }
    }

    private func previewSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            content()
        }
    }
}

private extension View {
    func previewBounds() -> some View {
        frame(maxWidth: 760, alignment: .leading)
    }
}

#Preview("Shared UI") {
    SharedUIPreviews()
        .frame(width: 920, height: 1120)
}
