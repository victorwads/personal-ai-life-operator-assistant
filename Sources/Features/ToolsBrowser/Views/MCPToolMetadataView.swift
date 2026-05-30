import SwiftUI

struct MCPToolMetadataView: View {
    let tool: any MCPToolDefinition

    var body: some View {
        DSCard(prominence: .emphasized) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: tool.icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(tool.name)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)

                        Text(tool.description)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        DSBadge(tool.group)

                        ForEach(tool.traits, id: \.rawValue) { trait in
                            DSBadge(trait.displayName)
                        }
                    }
                }
            }
        }
    }
}

struct MCPToolSectionCard<Content: View>: View {
    let title: String?
    let systemImage: String?
    private let content: Content

    init(
        title: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        if let title {
            DSTitledSection(title: title, systemImage: systemImage) {
                content
            }
        } else {
            DSCard(systemImage: systemImage) {
                content
            }
        }
    }
}

struct MCPToolCodeSection: View {
    let title: String
    let code: String

    var body: some View {
        MCPToolSectionCard(title: title) {
            DSCodeBlock(code)
        }
    }
}
