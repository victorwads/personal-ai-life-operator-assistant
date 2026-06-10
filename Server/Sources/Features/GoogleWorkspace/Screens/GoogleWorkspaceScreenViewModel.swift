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
    
    // Inputs for Milestone 3
    @Published var draftTo = ""
    @Published var draftCc = ""
    @Published var draftBcc = ""
    @Published var draftSubject = ""
    @Published var draftBody = ""
    @Published var replyMessageId = ""
    @Published var replyBody = ""
    @Published var eventTitle = ""
    @Published var eventDescription = ""
    @Published var eventLocation = ""
    @Published var eventStartDateTime = ""
    @Published var eventEndDateTime = ""
    @Published var eventAttendees = ""
    @Published var eventId = ""
    @Published var eventRecurrence = ""
    @Published var eventStatus = ""
    @Published var linkContactId = ""
    @Published var linkWhatsappChatId = ""
    @Published var linkGooglePersonId = ""
    @Published var lookupWhatsappChatId = ""
    @Published var lookupGooglePersonId = ""

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

    func testCreateDraft() {
        isLoading = true
        lastError = nil
        resultPreview = "Creating email draft..."
        Task {
            do {
                let ccVal = draftCc.isEmpty ? nil : draftCc
                let bccVal = draftBcc.isEmpty ? nil : draftBcc
                let draft = try await feature.gmailService.createDraftEmail(
                    to: draftTo,
                    cc: ccVal,
                    bcc: bccVal,
                    subject: draftSubject,
                    body: draftBody
                )
                let data = try JSONEncoder().encode(draft)
                let json = String(data: data, encoding: .utf8) ?? ""
                self.resultPreview = json
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to create email draft."
                self.isLoading = false
            }
        }
    }

    func testCreateReplyDraft() {
        isLoading = true
        lastError = nil
        resultPreview = "Creating reply draft..."
        Task {
            do {
                let draft = try await feature.gmailService.createDraftReply(
                    threadId: threadId,
                    messageId: replyMessageId,
                    body: replyBody
                )
                let data = try JSONEncoder().encode(draft)
                let json = String(data: data, encoding: .utf8) ?? ""
                self.resultPreview = json
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to create reply draft."
                self.isLoading = false
            }
        }
    }

    func testListCalendars() {
        isLoading = true
        lastError = nil
        resultPreview = "Listing calendars..."
        Task {
            do {
                let calendars = try await feature.calendarService.listCalendars()
                let data = try JSONEncoder().encode(calendars)
                let json = String(data: data, encoding: .utf8) ?? ""
                self.resultPreview = json
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to list calendars."
                self.isLoading = false
            }
        }
    }

    func testCreateCalendarEvent() {
        isLoading = true
        lastError = nil
        resultPreview = "Creating calendar event..."
        Task {
            do {
                let attendeesList = eventAttendees.isEmpty ? nil : eventAttendees.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let event = try await feature.calendarService.createCalendarEvent(
                    title: eventTitle,
                    description: eventDescription.isEmpty ? nil : eventDescription,
                    location: eventLocation.isEmpty ? nil : eventLocation,
                    startDateTime: eventStartDateTime,
                    endDateTime: eventEndDateTime,
                    attendees: attendeesList
                )
                let data = try JSONEncoder().encode(event)
                let json = String(data: data, encoding: .utf8) ?? ""
                self.resultPreview = json
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to create calendar event."
                self.isLoading = false
            }
        }
    }

    func testUpdateCalendarEvent() {
        isLoading = true
        lastError = nil
        resultPreview = "Updating calendar event..."
        Task {
            do {
                let attendeesList = eventAttendees.isEmpty ? nil : eventAttendees.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                let recurrenceList = eventRecurrence.isEmpty ? nil : eventRecurrence.components(separatedBy: ";")
                let event = try await feature.calendarService.updateCalendarEvent(
                    eventId: eventId,
                    title: eventTitle.isEmpty ? nil : eventTitle,
                    description: eventDescription.isEmpty ? nil : eventDescription,
                    location: eventLocation.isEmpty ? nil : eventLocation,
                    startDateTime: eventStartDateTime.isEmpty ? nil : eventStartDateTime,
                    endDateTime: eventEndDateTime.isEmpty ? nil : eventEndDateTime,
                    attendees: attendeesList,
                    recurrence: recurrenceList,
                    status: eventStatus.isEmpty ? nil : eventStatus
                )
                let data = try JSONEncoder().encode(event)
                let json = String(data: data, encoding: .utf8) ?? ""
                self.resultPreview = json
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to update calendar event."
                self.isLoading = false
            }
        }
    }

    func testDeleteCalendarEvent() {
        isLoading = true
        lastError = nil
        resultPreview = "Deleting calendar event..."
        Task {
            do {
                try await feature.calendarService.deleteCalendarEvent(eventId: eventId)
                self.resultPreview = "Successfully deleted calendar event with ID: \(eventId)"
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to delete calendar event."
                self.isLoading = false
            }
        }
    }

    func testLinkContactToWhatsAppChat() {
        isLoading = true
        lastError = nil
        resultPreview = "Linking contact to WhatsApp chat..."
        Task {
            do {
                guard var contact = try await feature.assistantContactRepository.getById(linkContactId) else {
                    self.resultPreview = "Contact not found."
                    self.isLoading = false
                    return
                }
                contact.whatsappChatId = linkWhatsappChatId
                try await feature.assistantContactRepository.save(contact)
                let data = try JSONEncoder().encode(contact)
                self.resultPreview = String(data: data, encoding: .utf8) ?? ""
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to link contact."
                self.isLoading = false
            }
        }
    }

    func testLinkGoogleContactToWhatsAppChat() {
        isLoading = true
        lastError = nil
        resultPreview = "Linking Google Contact to WhatsApp chat..."
        Task {
            do {
                var normalizedId = linkGooglePersonId
                if !normalizedId.hasPrefix("people/") {
                    normalizedId = "people/" + normalizedId
                }
                if var existing = try await feature.assistantContactRepository.findByGooglePersonId(normalizedId) {
                    existing.whatsappChatId = linkWhatsappChatId
                    try await feature.assistantContactRepository.save(existing)
                    let data = try JSONEncoder().encode(existing)
                    self.resultPreview = String(data: data, encoding: .utf8) ?? ""
                    self.isLoading = false
                    return
                }
                guard let googleContact = try await feature.contactsService.getContact(resourceName: normalizedId) else {
                    self.resultPreview = "Google Contact not found."
                    self.isLoading = false
                    return
                }
                let newContact = AssistantContact(
                    id: nil,
                    displayName: googleContact.displayName,
                    googlePersonId: normalizedId,
                    whatsappChatId: linkWhatsappChatId,
                    primaryPhone: googleContact.phoneNumbers.first,
                    primaryEmail: googleContact.emailAddresses.first
                )
                let saved = try await feature.assistantContactRepository.save(newContact)
                let data = try JSONEncoder().encode(saved)
                self.resultPreview = String(data: data, encoding: .utf8) ?? ""
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to link Google Contact."
                self.isLoading = false
            }
        }
    }

    func testLookupContactByChat() {
        isLoading = true
        lastError = nil
        resultPreview = "Looking up contact by WhatsApp Chat ID..."
        Task {
            do {
                guard let contact = try await feature.assistantContactRepository.findByWhatsappChatId(lookupWhatsappChatId) else {
                    self.resultPreview = "No linked contact found."
                    self.isLoading = false
                    return
                }
                let data = try JSONEncoder().encode(contact)
                self.resultPreview = String(data: data, encoding: .utf8) ?? ""
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to look up contact."
                self.isLoading = false
            }
        }
    }

    func testLookupContactByGoogleId() {
        isLoading = true
        lastError = nil
        resultPreview = "Looking up contact by Google Person ID..."
        Task {
            do {
                var normalizedId = lookupGooglePersonId
                if !normalizedId.hasPrefix("people/") {
                    normalizedId = "people/" + normalizedId
                }
                guard let contact = try await feature.assistantContactRepository.findByGooglePersonId(normalizedId) else {
                    self.resultPreview = "No linked contact found."
                    self.isLoading = false
                    return
                }
                let data = try JSONEncoder().encode(contact)
                self.resultPreview = String(data: data, encoding: .utf8) ?? ""
                self.isLoading = false
            } catch {
                self.lastError = error.localizedDescription
                self.resultPreview = "Failed to look up contact."
                self.isLoading = false
            }
        }
    }
}
