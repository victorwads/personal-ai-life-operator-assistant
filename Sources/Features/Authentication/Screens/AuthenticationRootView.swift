import SwiftUI

struct AuthenticationRootView: View {
    @EnvironmentObject private var authController: AuthStateController
    @State private var isSigningOut = false

    var body: some View {
        Group {
            switch authController.state {
            case .loading:
                loadingView
            case .unauthenticated:
                LoginScreen(
                    isLoading: false,
                    errorMessage: nil,
                    onGoogleSignIn: {
                        Task {
                            await authController.signInWithGoogle()
                        }
                    },
                    onRetry: {
                        Task {
                            await authController.load()
                        }
                    }
                )
            case .authenticated:
                if let session = authController.currentSession {
                    AuthenticatedPlaceholderScreen(
                        session: session,
                        isSigningOut: isSigningOut,
                        onSignOut: {
                            isSigningOut = true
                            Task {
                                await authController.signOut()
                                isSigningOut = false
                            }
                        }
                    )
                } else {
                    loadingView
                }
            case .failed(let message):
                LoginScreen(
                    isLoading: false,
                    errorMessage: message,
                    onGoogleSignIn: {
                        Task {
                            await authController.signInWithGoogle()
                        }
                    },
                    onRetry: {
                        Task {
                            await authController.load()
                        }
                    }
                )
            }
        }
        .task {
            if case .loading = authController.state {
                await authController.load()
            }
        }
        .onOpenURL { url in
            Task {
                await authController.handleOpenURL(url)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading authentication...")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
