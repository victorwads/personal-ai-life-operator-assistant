import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        systemImage: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}
