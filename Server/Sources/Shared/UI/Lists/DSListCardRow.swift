import SwiftUI

struct DSListCardRow<Badges: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let description: String?
    let systemImage: String?
    let badges: Badges
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        description: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder badges: () -> Badges = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.systemImage = systemImage
        self.badges = badges()
        self.trailing = trailing()
    }

    var body: some View {
        DSCard {
            HStack(alignment: .top, spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        trailing
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let description {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    badges
                }
            }
        }
    }
}
