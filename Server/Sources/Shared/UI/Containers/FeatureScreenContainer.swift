import SwiftUI

struct FeatureScreenContainer<Content: View>: View {
    let title: String?
    let subtitle: String?
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if title != nil || subtitle != nil {
                header
            }

            content
        }
        .padding(24)
        .dsFeatureHeaderContentInsets(DSFeatureHeaderContentInsets.none)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var header: some View {
        if let title {
            DSFeatureHeader(
                title: title,
                subtitle: subtitle
            )
        }
    }
}
