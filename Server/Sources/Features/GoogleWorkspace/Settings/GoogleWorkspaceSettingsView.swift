import SwiftUI
import UniformTypeIdentifiers

struct GoogleWorkspaceSettingsView: View {
    let wrapper: GoogleWorkspaceSettingsWrapper
    let authStatusProvider: @MainActor () -> GoogleWorkspaceAuthState

    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var redirectPort = ""
    @State private var authState = GoogleWorkspaceAuthState.disconnected

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: importCredentialsJSON) {
                Label("Import Credentials JSON...", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
            
            Divider()

            DSSettingsTextField(
                title: "Client ID",
                prompt: "Enter OAuth Client ID",
                helperText: "Create a Web/Desktop OAuth Client ID in your Google Cloud Console.",
                text: clientIdBinding
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Client Secret")
                    .font(.subheadline.weight(.semibold))
                
                SecureField("Enter OAuth Client Secret", text: clientSecretBinding)
                    .textFieldStyle(.roundedBorder)

                Text("Keep this secret secure. Never share or log this value.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Redirect Port")
                    .font(.subheadline.weight(.semibold))

                TextField("8089", text: redirectPortBinding)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                Text("The local port where the redirect server will listen for authorization callbacks (default: 8089). Must match the redirect URI in your Google Console.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Connection Status")
                    .font(.subheadline.weight(.semibold))

                statusBadge
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Enabled Scopes")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(wrapper.enabledScopes, id: \.self) { scope in
                        Text("• \(scope)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            load()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            authState = authStatusProvider()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch authState {
        case .disconnected:
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Disconnected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .connecting:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting...")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        case .connected(let scopes, let expiresAt):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                
                Text("Expires: \(expiresAt.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() {
        clientId = wrapper.clientId
        clientSecret = wrapper.clientSecret
        redirectPort = String(wrapper.redirectPort)
        authState = authStatusProvider()
    }

    private var clientIdBinding: Binding<String> {
        Binding {
            clientId
        } set: { value in
            clientId = value
            wrapper.clientId = value
        }
    }

    private var clientSecretBinding: Binding<String> {
        Binding {
            clientSecret
        } set: { value in
            clientSecret = value
            wrapper.clientSecret = value
        }
    }

    private var redirectPortBinding: Binding<String> {
        Binding {
            redirectPort
        } set: { value in
            redirectPort = value
            if let port = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                wrapper.redirectPort = port
            } else if value.isEmpty {
                wrapper.redirectPort = 8089
            }
        }
    }

    private func importCredentialsJSON() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let credentials = try GoogleWorkspaceSettingsWrapper.parseCredentials(from: data)
                self.clientId = credentials.clientId
                self.clientSecret = credentials.clientSecret
                self.wrapper.clientId = credentials.clientId
                self.wrapper.clientSecret = credentials.clientSecret
            } catch {
                print("Failed to import Google Workspace credentials: \(error.localizedDescription)")
            }
        }
    }
}
