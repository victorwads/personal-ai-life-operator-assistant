import SwiftUI

struct DSCard<Content: View>: View {
    let title: String?
    let systemImage: String?
    let prominence: Prominence
    private let content: Content

    enum Prominence {
        case normal
        case emphasized
    }

    init(
        title: String? = nil,
        systemImage: String? = nil,
        prominence: Prominence = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.prominence = prominence
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || systemImage != nil {
                header
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }

            if let title {
                Text(title)
                    .font(titleFont)
            }
        }
    }

    private var titleFont: Font {
        switch prominence {
        case .normal:
            return .headline
        case .emphasized:
            return .title3.weight(.semibold)
        }
    }
}
