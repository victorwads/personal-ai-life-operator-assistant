import SwiftUI

struct DSTitledSection<Trailing: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let prominence: Prominence
    let trailing: Trailing
    let content: Content

    enum Prominence {
        case normal
        case emphasized
    }

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        prominence: Prominence = .normal,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.prominence = prominence
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .padding(.top, 4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(titleFont)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                trailing
                    .padding(.top, 2)
            }

            DSCard {
                content
            }
        }
    }

    private var titleFont: Font {
        switch prominence {
        case .normal:
            return .title2.weight(.semibold)
        case .emphasized:
            return .title2.weight(.semibold)
        }
    }
}
