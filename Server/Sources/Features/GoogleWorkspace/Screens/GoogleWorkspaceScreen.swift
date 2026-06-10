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

                        DSTitledSection(title: "Milestone 3 — Drafts & Calendar CRUD") {
                            VStack(alignment: .leading, spacing: 16) {
                                // Create Draft Form
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Create Email Draft")
                                        .font(.subheadline.weight(.semibold))
                                    TextField("To (e.g. email@test.com)", text: $viewModel.draftTo)
                                        .textFieldStyle(.roundedBorder)
                                    HStack {
                                        TextField("CC (optional)", text: $viewModel.draftCc)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("BCC (optional)", text: $viewModel.draftBcc)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    TextField("Subject", text: $viewModel.draftSubject)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Body", text: $viewModel.draftBody)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Create Draft") {
                                        viewModel.testCreateDraft()
                                    }
                                    .disabled(viewModel.isLoading)
                                }
                                
                                Divider()
                                
                                // Create Reply Draft Form
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Create Thread Reply Draft")
                                        .font(.subheadline.weight(.semibold))
                                    TextField("Thread ID", text: $viewModel.threadId)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Original Message ID (from Header)", text: $viewModel.replyMessageId)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Reply Body", text: $viewModel.replyBody)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Create Reply Draft") {
                                        viewModel.testCreateReplyDraft()
                                    }
                                    .disabled(viewModel.isLoading)
                                }
                                
                                Divider()

                                // Calendar Event CRUD
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Calendar Event Operations")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Button("List Calendars") {
                                            viewModel.testListCalendars()
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                    
                                    TextField("Event ID (for update/delete)", text: $viewModel.eventId)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Title", text: $viewModel.eventTitle)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Description", text: $viewModel.eventDescription)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Location", text: $viewModel.eventLocation)
                                        .textFieldStyle(.roundedBorder)
                                    HStack {
                                        TextField("Start DateTime (ISO)", text: $viewModel.eventStartDateTime)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("End DateTime (ISO)", text: $viewModel.eventEndDateTime)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    TextField("Attendees (comma separated emails)", text: $viewModel.eventAttendees)
                                        .textFieldStyle(.roundedBorder)
                                    HStack {
                                        TextField("Recurrence (e.g. RRULE:FREQ=DAILY)", text: $viewModel.eventRecurrence)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("Status (e.g. confirmed)", text: $viewModel.eventStatus)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    HStack {
                                        Button("Create Event") {
                                            viewModel.testCreateCalendarEvent()
                                        }
                                        .disabled(viewModel.isLoading)
                                        
                                        Button("Update Event") {
                                            viewModel.testUpdateCalendarEvent()
                                        }
                                        .disabled(viewModel.isLoading)
                                        
                                        Button("Delete Event") {
                                            viewModel.testDeleteCalendarEvent()
                                        }
                                        .tint(.red)
                                        .disabled(viewModel.isLoading)
                                    }
                                }
                            }
                        }

                        DSTitledSection(title: "Milestone 3 — Contact Identity Linking") {
                            VStack(alignment: .leading, spacing: 16) {
                                // Link Contact to WhatsApp Chat
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Link Contact to WhatsApp Chat")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        TextField("Contact ID", text: $viewModel.linkContactId)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("WhatsApp Chat ID", text: $viewModel.linkWhatsappChatId)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Link Contact") {
                                            viewModel.testLinkContactToWhatsAppChat()
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                }

                                Divider()

                                // Link Google Contact to WhatsApp Chat
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Link Google Contact to WhatsApp Chat")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        TextField("Google Person ID", text: $viewModel.linkGooglePersonId)
                                            .textFieldStyle(.roundedBorder)
                                        TextField("WhatsApp Chat ID", text: $viewModel.linkWhatsappChatId)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Link Google Contact") {
                                            viewModel.testLinkGoogleContactToWhatsAppChat()
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                }

                                Divider()

                                // Contact Lookups
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Contact Identity Lookup")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        TextField("Lookup WhatsApp Chat ID", text: $viewModel.lookupWhatsappChatId)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Lookup By Chat") {
                                            viewModel.testLookupContactByChat()
                                        }
                                        .disabled(viewModel.isLoading)
                                    }
                                    HStack {
                                        TextField("Lookup Google Person ID", text: $viewModel.lookupGooglePersonId)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Lookup By Google ID") {
                                            viewModel.testLookupContactByGoogleId()
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
