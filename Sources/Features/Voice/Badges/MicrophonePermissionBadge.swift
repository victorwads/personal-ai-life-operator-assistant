import SwiftUI

struct MicrophonePermissionBadge: View {
    let isAuthorized: Bool
    let speechRecognitionAuthorized: Bool
    let onRequestPermission: () -> Void

    var body: some View {
        if isAuthorized && speechRecognitionAuthorized {
            EmptyView()
        } else {
            Button {
                onRequestPermission()
            } label: {
                StatusBadge(
                    title: "Voice",
                    isOnline: false,
                    help: "Microphone and Speech Recognition permissions are required for voice answers. Click to request them."
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("Authorized (hidden)") {
    MicrophonePermissionBadge(isAuthorized: true, speechRecognitionAuthorized: true, onRequestPermission: {})
        .padding()
}

#Preview("Not authorized") {
    MicrophonePermissionBadge(isAuthorized: false, speechRecognitionAuthorized: false, onRequestPermission: {})
        .padding()
}
