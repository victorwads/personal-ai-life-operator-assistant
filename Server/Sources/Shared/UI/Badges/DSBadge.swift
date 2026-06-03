import SwiftUI

struct DSBadge: View {
    let text: String
    let secondaryText: String?
    let systemImage: String?
    let style: Style

    enum Style {
        case neutral
        case info
        case success
        case warning
        case danger
    }

    init(
        _ text: String,
        secondaryText: String? = nil,
        systemImage: String? = nil,
        style: Style = .neutral
    ) {
        self.text = text
        self.secondaryText = secondaryText
        self.systemImage = systemImage
        self.style = style
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }

            Text(text)
                .font(.caption.weight(.semibold))

            if let secondaryText {
                Text(secondaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(foregroundStyle)
        .background(backgroundStyle, in: Capsule())
    }

    private var foregroundStyle: AnyShapeStyle {
        switch style {
        case .neutral:
            return AnyShapeStyle(.secondary)
        case .info:
            return AnyShapeStyle(.blue)
        case .success:
            return AnyShapeStyle(.green)
        case .warning:
            return AnyShapeStyle(.orange)
        case .danger:
            return AnyShapeStyle(.red)
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .neutral:
            return AnyShapeStyle(.quaternary)
        case .info:
            return AnyShapeStyle(.blue.opacity(0.14))
        case .success:
            return AnyShapeStyle(.green.opacity(0.14))
        case .warning:
            return AnyShapeStyle(.orange.opacity(0.14))
        case .danger:
            return AnyShapeStyle(.red.opacity(0.14))
        }
    }
}
