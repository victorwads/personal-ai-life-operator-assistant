import SwiftUI

struct AuthenticatedPlaceholderScreen: View {
    let session: AuthSession
    let isSigningOut: Bool
    let onSignOut: () -> Void

    init(session: AuthSession, isSigningOut: Bool, onSignOut: @escaping () -> Void) {
        self.session = session
        self.isSigningOut = isSigningOut
        self.onSignOut = onSignOut
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Authenticated")
                .font(.largeTitle.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                labeledValue(title: "UID", value: session.user.uid)
                labeledValue(title: "Email", value: session.user.email ?? "Not available")
                labeledValue(title: "Display Name", value: session.user.displayName ?? "Not available")
            }

            Text("App shell will be loaded here. Profiles, Tray, Runtime, and profile-scoped services come in the next pass.")
                .foregroundStyle(.secondary)

            Button {
                onSignOut()
            } label: {
                HStack {
                    if isSigningOut {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isSigningOut ? "Signing Out..." : "Sign Out")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isSigningOut)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420, alignment: .topLeading)
    }

    private func labeledValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }
}
