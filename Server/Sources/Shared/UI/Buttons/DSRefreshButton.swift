import SwiftUI

struct DSRefreshButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    init(
        title: String = "Refresh",
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
        }
        .disabled(isLoading)
    }
}
