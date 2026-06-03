import SwiftUI

struct DSMessageBubbleRow<Content: View, Footer: View>: View {
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
        HStack {
            if alignment == .trailing {
                Spacer(minLength: 48)
            }

            DSMessageBubble(
                alignment: alignment,
                title: title,
                subtitle: subtitle,
                content: { content },
                footer: { footer }
            )
            .frame(maxWidth: 520, alignment: alignment == .leading ? .leading : .trailing)

            if alignment == .leading {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
