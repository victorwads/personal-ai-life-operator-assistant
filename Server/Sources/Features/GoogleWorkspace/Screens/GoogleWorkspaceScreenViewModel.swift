import SwiftUI

@MainActor
final class GoogleWorkspaceScreenViewModel: ObservableObject {
    private let feature: GoogleWorkspaceFeature

    @Published var authState: GoogleWorkspaceAuthState = .disconnected
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var resultPreview = ""

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
}
