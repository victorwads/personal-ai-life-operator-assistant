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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
            }

            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
