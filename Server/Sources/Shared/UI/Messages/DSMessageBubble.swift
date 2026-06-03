import SwiftUI

enum DSMessageBubbleAlignment: Equatable {
    case leading
    case trailing
}

struct DSMessageBubble<Content: View, Footer: View>: View {
    let alignment: DSMessageBubbleAlignment
    let title: String?
    let subtitle: String?
    let content: Content
    let footer: Footer

    init(
        alignment: DSMessageBubbleAlignment,
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.alignment = alignment
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 8) {
            if title != nil || subtitle != nil {
                VStack(alignment: stackAlignment, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(titleStyle)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            }

            content
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            footer
                .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderStyle, lineWidth: 1)
        )
    }

    private var stackAlignment: HorizontalAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }

    private var titleStyle: AnyShapeStyle {
        switch alignment {
        case .leading:
            return AnyShapeStyle(.primary)
        case .trailing:
            return AnyShapeStyle(.white.opacity(0.92))
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch alignment {
        case .leading:
            return AnyShapeStyle(.quaternary)
        case .trailing:
            return AnyShapeStyle(.tint)
        }
    }

    private var borderStyle: AnyShapeStyle {
        switch alignment {
        case .leading:
            return AnyShapeStyle(.quaternary)
        case .trailing:
            return AnyShapeStyle(.tint.opacity(0.35))
        }
    }
}
