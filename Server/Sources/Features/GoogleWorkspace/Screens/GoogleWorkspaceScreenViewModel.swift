import SwiftUI

@MainActor
final class GoogleWorkspaceScreenViewModel: ObservableObject {
    private let feature: GoogleWorkspaceFeature

    @Published var authState: GoogleWorkspaceAuthState = .disconnected
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var resultPreview = ""

    // Inputs for testing Gmail operational tools
    @Published var searchQuery = ""
    @Published var messageId = ""
    @Published var threadId = ""
    @Published var labelName = ""

    init(feature: GoogleWorkspaceFeature) {
        self.feature = feature
        refreshState()
    }

    func refreshState() {
        self.authState = feature.authService.state
    }

    func connect() {
        isLoading = true
        lastError = nil
        resultPreview = "Starting OAuth 2.0 flow in your browser..."

        Task {
            do {
                try await feature.authService.startOAuthFlow(forceConsent: true)
                self.refreshState()
                self.resultPreview = "Successfully connected to Google Workspace!"
                self.isLoading = false
            } catch {
                self.refreshState()
                self.lastError = error.localizedDescription
                self.resultPreview = "Authentication failed."
                self.isLoading = false
            }
        }
    }

    func disconnect() {
        feature.authService.disconnect()
        refreshState()
        resultPreview = "Disconnected."
        lastError = nil
    }

    func testGmail() {
        isLoading = true
        lastError = nil
        resultPreview = "Fetching recent emails..."

        Task {
            do {
                let emails = try await feature.gmailService.listRecentEmails(maxResults: 5)
                self.isLoading = false
                if emails.isEmpty {
                    self.resultPreview = "No emails found in the inbox."
                } else {
                    let formatted = emails.map { email in
                        """
                        Subject: \(email.subject)
                        From: \(email.from)
                        Date: \(email.date)
                        Snippet: \(email.snippet)
                        --------------------------------------------
                        """
                    }.joined(separator: "\n\n")
                    self.resultPreview = formatted
                }
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to list emails."
                self.isLoading = false
            }
        }
    }

    func testCalendar() {
        isLoading = true
        lastError = nil
        resultPreview = "Fetching upcoming calendar events..."

        Task {
            do {
                let events = try await feature.calendarService.listUpcomingEvents(maxResults: 5)
                self.isLoading = false
                if events.isEmpty {
                    self.resultPreview = "No upcoming calendar events found."
                } else {
                    let formatted = events.map { event in
                        let startStr = event.start.dateTime ?? event.start.date ?? "No start time"
                        let endStr = event.end.dateTime ?? event.end.date ?? "No end time"
                        return """
                        Event: \(event.summary ?? "(No Title)")
                        Time: \(startStr) to \(endStr)
                        Location: \(event.location ?? "N/A")
                        Description: \(event.description ?? "N/A")
                        Link: \(event.htmlLink ?? "N/A")
                        --------------------------------------------
                        """
                    }.joined(separator: "\n\n")
                    self.resultPreview = formatted
                }
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to list calendar events."
                self.isLoading = false
            }
        }
    }

    func testContacts() {
        isLoading = true
        lastError = nil
        resultPreview = "Fetching connections..."

        Task {
            do {
                let contacts = try await feature.contactsService.listContacts(pageSize: 5)
                self.isLoading = false
                if contacts.isEmpty {
                    self.resultPreview = "No contacts found."
                } else {
                    let formatted = contacts.map { contact in
                        let emails = contact.emailAddresses.joined(separator: ", ")
                        let phones = contact.phoneNumbers.joined(separator: ", ")
                        return """
                        Name: \(contact.displayName)
                        Emails: \(emails.isEmpty ? "None" : emails)
                        Phones: \(phones.isEmpty ? "None" : phones)
                        Org: \(contact.organizationName ?? "N/A")
                        --------------------------------------------
                        """
                    }.joined(separator: "\n\n")
                    self.resultPreview = formatted
                }
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to list contacts."
                self.isLoading = false
            }
        }
    }

    // MARK: - Gmail Operational Tools Tests

    func testSearchEmails() {
        isLoading = true
        lastError = nil
        resultPreview = "Searching emails for query: '\(searchQuery)'..."

        Task {
            do {
                let emails = try await feature.gmailService.searchEmails(query: searchQuery)
                self.isLoading = false
                if emails.isEmpty {
                    self.resultPreview = "No matching emails found."
                } else {
                    let formatted = emails.map { email in
                        """
                        Message ID: \(email.messageId)
                        Thread ID: \(email.threadId)
                        History ID: \(email.historyId)
                        Subject: \(email.subject)
                        From: \(email.from)
                        To: \(email.to)
                        Date: \(email.date)
                        Snippet: \(email.snippet)
                        Labels: \(email.labelIds.joined(separator: ", "))
                        --------------------------------------------
                        """
                    }.joined(separator: "\n\n")
                    self.resultPreview = formatted
                }
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to search emails."
                self.isLoading = false
            }
        }
    }

    func testListLabels() {
        isLoading = true
        lastError = nil
        resultPreview = "Fetching labels list..."

        Task {
            do {
                let labels = try await feature.gmailService.listLabels()
                self.isLoading = false
                if labels.isEmpty {
                    self.resultPreview = "No labels found."
                } else {
                    let formatted = labels.map { label in
                        "• ID: \(label.id) | Name: \(label.name) | Type: \(label.type)"
                    }.joined(separator: "\n")
                    self.resultPreview = formatted
                }
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to list labels."
                self.isLoading = false
            }
        }
    }

    func testCreateLabel() {
        let trimmedName = labelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastError = "Please enter a valid label name."
            return
        }

        isLoading = true
        lastError = nil
        resultPreview = "Creating label '\(trimmedName)'..."

        Task {
            do {
                let label = try await feature.gmailService.createLabel(name: trimmedName)
                self.isLoading = false
                self.resultPreview = "Label created successfully!\nID: \(label.id)\nName: \(label.name)\nType: \(label.type)"
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to create label."
                self.isLoading = false
            }
        }
    }

    func testGetEmailContent() {
        let trimmedId = messageId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            lastError = "Please enter a message ID."
            return
        }

        isLoading = true
        lastError = nil
        resultPreview = "Fetching message content for \(trimmedId)..."

        Task {
            do {
                let email = try await feature.gmailService.getEmailContent(messageId: trimmedId)
                self.isLoading = false
                let body = email.plainTextBody.isEmpty ? email.htmlBody : email.plainTextBody
                var formatted = """
                Message ID: \(email.messageId)
                Thread ID: \(email.threadId)
                History ID: \(email.historyId)
                Subject: \(email.subject)
                From: \(email.from)
                To: \(email.to)
                CC: \(email.cc ?? "N/A")
                BCC: \(email.bcc ?? "N/A")
                Date: \(email.date)
                Labels: \(email.labelIds.joined(separator: ", "))
                Snippet: \(email.snippet)
                ----------------------------------------------------------------------
                Body:
                \(body)
                """

                if !email.attachmentsMetadata.isEmpty {
                    let attachmentsStr = email.attachmentsMetadata.map {
                        "  - Filename: \($0.filename) | Size: \($0.size) bytes | ID: \($0.attachmentId)"
                    }.joined(separator: "\n")
                    formatted += "\n\nAttachments:\n\(attachmentsStr)"
                }

                self.resultPreview = formatted
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to get email content."
                self.isLoading = false
            }
        }
    }

    func testGetEmailThread() {
        let trimmedId = threadId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            lastError = "Please enter a thread ID."
            return
        }

        isLoading = true
        lastError = nil
        resultPreview = "Fetching thread conversation for \(trimmedId)..."

        Task {
            do {
                let thread = try await feature.gmailService.getThread(threadId: trimmedId)
                self.isLoading = false

                let formattedMessages = thread.messages.map { msg in
                    let body = msg.plainTextBody.isEmpty ? msg.htmlBody : msg.plainTextBody
                    return """
                    ----------------------------------------------------------------------
                    Message ID: \(msg.messageId)
                    From: \(msg.from)
                    To: \(msg.to)
                    Date: \(msg.date)
                    Snippet: \(msg.snippet)
                    Body:
                    \(body)
                    """
                }.joined(separator: "\n\n")

                self.resultPreview = "Thread ID: \(thread.threadId) (\(thread.messages.count) messages)\n\(formattedMessages)"
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to get thread."
                self.isLoading = false
            }
        }
    }

    func testAssistantDelete() {
        let trimmedId = messageId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty else {
            lastError = "Please enter a message ID."
            return
        }

        isLoading = true
        lastError = nil
        resultPreview = "Executing Assistant Delete on message \(trimmedId)..."

        Task {
            do {
                let result = try await feature.gmailService.assistantDeleteEmail(messageId: trimmedId)
                self.isLoading = false
                self.resultPreview = result
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to perform Assistant Delete."
                self.isLoading = false
            }
        }
    }
}
