import SwiftUI

struct GoogleWorkspaceScreen: View {
    let feature: GoogleWorkspaceFeature
    
    @StateObject private var viewModel: GoogleWorkspaceScreenViewModel

    init(feature: GoogleWorkspaceFeature) {
        self.feature = feature
        self._viewModel = StateObject(wrappedValue: GoogleWorkspaceScreenViewModel(feature: feature))
    }

    var body: some View {
        FeatureScreenContainer(
            title: "Google Workspace",
            subtitle: "Manage OAuth connection, view credentials, and test integration status."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Auth Status Card
                    DSCard(title: "Authentication Status", systemImage: "lock.shield", prominence: .emphasized) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                statusDot
                                Text(statusText)
                                    .font(.headline)
                                Spacer()
                            }
                            
                            if case .connected(_, let expiresAt) = viewModel.authState {
                                Text("Token expires: \(expiresAt.formatted())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 12) {
                                if isConnected {
                                    Button(action: {
                                        viewModel.disconnect()
                                    }) {
                                        Text("Disconnect")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                } else {
                                    Button(action: {
                                        viewModel.connect()
                                    }) {
                                        Text("Connect Google Workspace")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(viewModel.isLoading)
                                }

                                if viewModel.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                    }

                    // Test Operations Section
                    if isConnected {
                        DSTitledSection(title: "Test Integrations") {
                            VStack(alignment: .leading, spacing: 16) {
                                // Basic read tests
                                HStack(spacing: 12) {
                                    Button(action: { viewModel.testGmail() }) {
                                        Label("Test Gmail List", systemImage: "envelope")
                                    }
                                    .disabled(viewModel.isLoading)

                                    Button(action: { viewModel.testCalendar() }) {
                                        Label("Test Calendar", systemImage: "calendar")
                                    }
                                    .disabled(viewModel.isLoading)

                                    Button(action: { viewModel.testContacts() }) {
                                        Label("Test Contacts", systemImage: "person.crop.circle")
                                    }
                                    .disabled(viewModel.isLoading)

                                    Button(action: { viewModel.testListLabels() }) {
                                        Label("List Labels", systemImage: "tag")
                                    }
                                    .disabled(viewModel.isLoading)
                                }
                                
                                Divider()

                                // Gmail Search
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Gmail Search Query")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        TextField("e.g. from:boss or is:unread", text: $viewModel.searchQuery)
                                            .textFieldStyle(.roundedBorder)
                                        Button(action: { viewModel.testSearchEmails() }) {
                                            Text("Search Emails")
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                }

                                // Gmail Label Creation
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Gmail Label Name")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        TextField("e.g. Assistant/Deleted", text: $viewModel.labelName)
                                            .textFieldStyle(.roundedBorder)
                                        Button(action: { viewModel.testCreateLabel() }) {
                                            Text("Create Test Label")
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                }

                                // Message Operations
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Gmail Message ID")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        TextField("Enter Message ID", text: $viewModel.messageId)
                                            .textFieldStyle(.roundedBorder)
                                        Button(action: { viewModel.testGetEmailContent() }) {
                                            Text("Get Email Content")
                                        }
                                        .disabled(viewModel.isLoading)
                                        
                                        Button(action: { viewModel.testAssistantDelete() }) {
                                            Text("Assistant Delete")
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                        .disabled(viewModel.isLoading)
                                    }
                                }

                                // Thread Operations
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Gmail Thread ID")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        TextField("Enter Thread ID", text: $viewModel.threadId)
                                            .textFieldStyle(.roundedBorder)
                                        Button(action: { viewModel.testGetEmailThread() }) {
                                            Text("Get Email Thread")
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                }
                            }
                        }
                    } else {
                        DSCard(title: "Configuration Required", systemImage: "exclamationmark.triangle") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("To connect, you must configure your OAuth Client ID and Secret in settings:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Text("1. Go to Settings > Google Workspace.\n2. Paste your Google Cloud Console Credentials.\n3. Return here and click 'Connect'.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Error Section
                    if let lastError = viewModel.lastError {
                        DSCard(title: "Last Error", systemImage: "xmark.octagon.fill") {
                            Text(lastError)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }

                    // Results Preview Section
                    if !viewModel.resultPreview.isEmpty {
                        DSTitledSection(title: "Operation Log / Result Preview") {
                            DSCodeBlock(viewModel.resultPreview)
                                .frame(minHeight: 200, maxHeight: 400)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            viewModel.refreshState()
        }
    }

    private var isConnected: Bool {
        if case .connected = viewModel.authState {
            return true
        }
        return false
    }

    private var statusText: String {
        switch viewModel.authState {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        switch viewModel.authState {
        case .disconnected:
            Circle().fill(.red).frame(width: 10, height: 10)
        case .connecting:
            Circle().fill(.blue).frame(width: 10, height: 10)
        case .connected:
            Circle().fill(.green).frame(width: 10, height: 10)
        }
    }
}
