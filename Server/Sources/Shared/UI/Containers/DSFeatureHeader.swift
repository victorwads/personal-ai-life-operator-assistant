import SwiftUI

enum DSFeatureHeaderContentInsets {
    static let standard = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    static let none = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

private struct DSFeatureHeaderContentInsetsKey: EnvironmentKey {
    static let defaultValue: EdgeInsets? = nil
}

extension EnvironmentValues {
    var dsFeatureHeaderContentInsets: EdgeInsets? {
        get { self[DSFeatureHeaderContentInsetsKey.self] }
        set { self[DSFeatureHeaderContentInsetsKey.self] = newValue }
    }
}

extension View {
    func dsFeatureHeaderContentInsets(_ insets: EdgeInsets?) -> some View {
        environment(\.dsFeatureHeaderContentInsets, insets)
    }
}

struct DSFeatureHeader<Trailing: View>: View {
    @Environment(\.dsFeatureHeaderContentInsets) private var inheritedContentInsets

    private let wideLayoutMinimumWidth: CGFloat = 460

    let title: String
    let subtitle: String?
    let systemImage: String?
    let contentInsets: EdgeInsets?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        contentInsets: EdgeInsets? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.contentInsets = contentInsets
        self.trailing = trailing()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
                .frame(minWidth: wideLayoutMinimumWidth, alignment: .leading)

            compactLayout
        }
        .padding(contentInsets ?? inheritedContentInsets ?? DSFeatureHeaderContentInsets.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            titleBlock

            Spacer(minLength: 16)

            trailing
                .padding(.top, 4)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleBlock

            HStack {
                Spacer(minLength: 0)
                trailing
            }
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
