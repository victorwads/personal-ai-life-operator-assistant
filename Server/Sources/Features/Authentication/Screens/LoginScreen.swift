import SwiftUI

struct LoginScreen: View {
    let isLoading: Bool
    let errorMessage: String?
    let onGoogleSignIn: () -> Void
    let onRetry: () -> Void

    init(
        isLoading: Bool,
        errorMessage: String?,
        onGoogleSignIn: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onGoogleSignIn = onGoogleSignIn
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AI Assistant Hub")
                .font(.largeTitle.weight(.semibold))

            Text("Authentication is required to continue. Sign in with Google to load your account and prepare the app shell.")
                .font(.body)
                .foregroundStyle(.secondary)

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign-in error")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            GoogleSignInButtonView(isLoading: isLoading, action: onGoogleSignIn)

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderless)
            .disabled(isLoading)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420, alignment: .topLeading)
    }
}
