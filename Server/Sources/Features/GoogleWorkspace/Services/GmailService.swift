import Foundation

@MainActor
final class GmailService {
    private let httpClient: GoogleWorkspaceHTTPClient

    init(httpClient: GoogleWorkspaceHTTPClient) {
        self.httpClient = httpClient
    }

    func listRecentEmails(maxResults: Int = 10, query: String? = nil) async throws -> [GoogleEmailSummary] {
        var queryItems = [
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        if let query = query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }

        let listUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
        let listResponse: GmailMessagesListResponse = try await httpClient.get(listUrl, queryItems: queryItems)

        guard let messageRefs = listResponse.messages, !messageRefs.isEmpty else {
            return []
        }

        // Fetch details for each message in parallel
        return try await withThrowingTaskGroup(of: GoogleEmailSummary.self) { group in
            for ref in messageRefs {
                group.addTask {
                    try await self.fetchMessageDetail(id: ref.id)
                }
            }

            var summaries: [GoogleEmailSummary] = []
            for try await summary in group {
                summaries.append(summary)
            }

            // Sort summaries by internalDate descending (most recent first)
            return summaries.sorted { (a, b) -> Bool in
                let aDate = Int64(a.internalDate) ?? 0
                let bDate = Int64(b.internalDate) ?? 0
                return aDate > bDate
            }
        }
    }

    func searchEmails(query: String, maxResults: Int = 20) async throws -> [GoogleEmailSummary] {
        return try await listRecentEmails(maxResults: maxResults, query: query)
    }

    func getEmailContent(messageId: String) async throws -> GoogleEmailContent {
        let detailUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)"
        let queryItems = [
            URLQueryItem(name: "format", value: "full")
        ]

        let response: GmailFullMessageResponse = try await httpClient.get(detailUrl, queryItems: queryItems)

        let headers = response.payload?.headers ?? []
        let fromValue = findHeader(name: "From", in: headers)
        let toValue = findHeader(name: "To", in: headers)
        let ccValue = findHeader(name: "Cc", in: headers)
        let bccValue = findHeader(name: "Bcc", in: headers)
        let subjectValue = findHeader(name: "Subject", in: headers)
        let dateValue = findHeader(name: "Date", in: headers)

        var plainText = ""
        var html = ""
        var attachments: [GoogleAttachmentMetadata] = []

        extractBodyParts(payload: response.payload, plainText: &plainText, html: &html, attachments: &attachments)

        return GoogleEmailContent(
            messageId: response.id,
            threadId: response.threadId,
            historyId: response.historyId ?? "0",
            labelIds: response.labelIds ?? [],
            subject: subjectValue,
            from: fromValue,
            to: toValue,
            cc: ccValue.isEmpty ? nil : ccValue,
            bcc: bccValue.isEmpty ? nil : bccValue,
            date: dateValue,
            snippet: response.snippet ?? "",
            plainTextBody: plainText,
            htmlBody: html,
            attachmentsMetadata: attachments,
            internalDate: response.internalDate ?? "0"
        )
    }

    func getThread(threadId: String) async throws -> GoogleEmailThread {
        let threadUrl = "https://gmail.googleapis.com/gmail/v1/users/me/threads/\(threadId)"
        let queryItems = [
            URLQueryItem(name: "format", value: "full")
        ]

        let response: GmailThreadResponse = try await httpClient.get(threadUrl, queryItems: queryItems)

        let messages = response.messages ?? []
        let mappedMessages = messages.map { msg -> GoogleEmailContent in
            let headers = msg.payload?.headers ?? []
            let fromValue = self.findHeader(name: "From", in: headers)
            let toValue = self.findHeader(name: "To", in: headers)
            let ccValue = self.findHeader(name: "Cc", in: headers)
            let bccValue = self.findHeader(name: "Bcc", in: headers)
            let subjectValue = self.findHeader(name: "Subject", in: headers)
            let dateValue = self.findHeader(name: "Date", in: headers)

            var plainText = ""
            var html = ""
            var attachments: [GoogleAttachmentMetadata] = []

            self.extractBodyParts(payload: msg.payload, plainText: &plainText, html: &html, attachments: &attachments)

            return GoogleEmailContent(
                messageId: msg.id,
                threadId: msg.threadId,
                historyId: msg.historyId ?? "0",
                labelIds: msg.labelIds ?? [],
                subject: subjectValue,
                from: fromValue,
                to: toValue,
                cc: ccValue.isEmpty ? nil : ccValue,
                bcc: bccValue.isEmpty ? nil : bccValue,
                date: dateValue,
                snippet: msg.snippet ?? "",
                plainTextBody: plainText,
                htmlBody: html,
                attachmentsMetadata: attachments,
                internalDate: msg.internalDate ?? "0"
            )
        }

        return GoogleEmailThread(
            threadId: response.id,
            messages: mappedMessages
        )
    }

    func listLabels() async throws -> [GoogleGmailLabel] {
        let labelsUrl = "https://gmail.googleapis.com/gmail/v1/users/me/labels"
        let response: GmailLabelsListResponse = try await httpClient.get(labelsUrl)
        return response.labels ?? []
    }

    func createLabel(name: String) async throws -> GoogleGmailLabel {
        let createUrl = "https://gmail.googleapis.com/gmail/v1/users/me/labels"
        let body = CreateLabelRequest(name: name)
        let response: GoogleGmailLabel = try await httpClient.post(createUrl, body: body)
        return response
    }

    func addLabelToMessage(messageId: String, labelId: String) async throws {
        let modifyUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)/modify"
        let body = ModifyMessageLabelsRequest(addLabelIds: [labelId], removeLabelIds: [])
        let _: GmailMessageDetailResponse = try await httpClient.post(modifyUrl, body: body)
    }

    func removeLabelFromMessage(messageId: String, labelId: String) async throws {
        let modifyUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)/modify"
        let body = ModifyMessageLabelsRequest(addLabelIds: [], removeLabelIds: [labelId])
        let _: GmailMessageDetailResponse = try await httpClient.post(modifyUrl, body: body)
    }

    func assistantDeleteEmail(messageId: String) async throws -> String {
        let labels = try await listLabels()
        var targetLabelId = ""

        if let existing = labels.first(where: { $0.name.caseInsensitiveCompare("Assistant/Deleted") == .orderedSame }) {
            targetLabelId = existing.id
        } else {
            let newLabel = try await createLabel(name: "Assistant/Deleted")
            targetLabelId = newLabel.id
        }

        let modifyUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)/modify"
        let body = ModifyMessageLabelsRequest(addLabelIds: [targetLabelId], removeLabelIds: ["INBOX"])
        let _: GmailMessageDetailResponse = try await httpClient.post(modifyUrl, body: body)

        return "Applied label 'Assistant/Deleted' (ID: \(targetLabelId)) and removed 'INBOX' from message \(messageId)."
    }

    func markEmailAsRead(messageId: String) async throws {
        let modifyUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)/modify"
        let body = ModifyMessageLabelsRequest(addLabelIds: [], removeLabelIds: ["UNREAD"])
        let _: GmailMessageDetailResponse = try await httpClient.post(modifyUrl, body: body)
    }

    func markEmailAsUnread(messageId: String) async throws {
        let modifyUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageId)/modify"
        let body = ModifyMessageLabelsRequest(addLabelIds: ["UNREAD"], removeLabelIds: [])
        let _: GmailMessageDetailResponse = try await httpClient.post(modifyUrl, body: body)
    }

    // MARK: - Private Helpers

    private func fetchMessageDetail(id: String) async throws -> GoogleEmailSummary {
        let detailUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)"
        let queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "metadataHeaders", value: "To"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "Date")
        ]

        let response: GmailMessageDetailResponse = try await httpClient.get(detailUrl, queryItems: queryItems)

        let headers = response.payload?.headers ?? []
        let fromValue = findHeader(name: "From", in: headers)
        let toValue = findHeader(name: "To", in: headers)
        let subjectValue = findHeader(name: "Subject", in: headers)
        let dateValue = findHeader(name: "Date", in: headers)

        return GoogleEmailSummary(
            id: response.id,
            messageId: response.id,
            threadId: response.threadId,
            historyId: response.historyId ?? "0",
            snippet: response.snippet ?? "",
            from: fromValue,
            to: toValue,
            subject: subjectValue,
            date: dateValue,
            internalDate: response.internalDate ?? "0",
            labelIds: response.labelIds ?? []
        )
    }

    private func findHeader(name: String, in headers: [GmailMessageDetailResponse.Payload.Header]) -> String {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value ?? ""
    }

    private func decodeBase64URL(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let mod = base64.count % 4
        if mod > 0 {
            base64 += String(repeating: "=", count: 4 - mod)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func extractBodyParts(
        payload: GmailFullMessageResponse.Payload?,
        plainText: inout String,
        html: inout String,
        attachments: inout [GoogleAttachmentMetadata]
    ) {
        guard let payload = payload else { return }

        if let parts = payload.parts {
            for part in parts {
                extractBodyFromPart(part, plainText: &plainText, html: &html, attachments: &attachments)
            }
        } else if let bodyData = payload.body?.data, !bodyData.isEmpty {
            if let decoded = decodeBase64URL(bodyData) {
                if let mime = payload.mimeType, mime.contains("text/html") {
                    html += decoded
                } else {
                    plainText += decoded
                }
            }
        }
    }

    private func extractBodyFromPart(
        _ part: GmailFullMessageResponse.Payload.Part,
        plainText: inout String,
        html: inout String,
        attachments: inout [GoogleAttachmentMetadata]
    ) {
        if let filename = part.filename, !filename.isEmpty, let attachmentId = part.body?.attachmentId, !attachmentId.isEmpty {
            let metadata = GoogleAttachmentMetadata(
                attachmentId: attachmentId,
                filename: filename,
                mimeType: part.mimeType ?? "application/octet-stream",
                size: part.body?.size ?? 0
            )
            attachments.append(metadata)
        } else {
            if let mimeType = part.mimeType {
                if mimeType.contains("text/plain"), let bodyData = part.body?.data, !bodyData.isEmpty {
                    if let decoded = decodeBase64URL(bodyData) {
                        plainText += decoded
                    }
                } else if mimeType.contains("text/html"), let bodyData = part.body?.data, !bodyData.isEmpty {
                    if let decoded = decodeBase64URL(bodyData) {
                        html += decoded
                    }
                }
            }
        }

        if let nestedParts = part.parts {
            for nested in nestedParts {
                extractBodyFromPart(nested, plainText: &plainText, html: &html, attachments: &attachments)
            }
        }
    }
}

// MARK: - Encodable Requests

struct CreateLabelRequest: Encodable {
    let name: String
    let labelListVisibility: String = "labelShow"
    let messageListVisibility: String = "show"
}

struct ModifyMessageLabelsRequest: Encodable {
    let addLabelIds: [String]
    let removeLabelIds: [String]
}

// MARK: - Decodable Helpers

struct GmailMessagesListResponse: Decodable {
    struct MessageRef: Decodable {
        let id: String
        let threadId: String
    }
    let messages: [MessageRef]?
    let nextPageToken: String?
}

struct GmailMessageDetailResponse: Decodable {
    struct Payload: Decodable {
        struct Header: Decodable {
            let name: String
            let value: String
        }
        let headers: [Header]?
    }
    let id: String
    let threadId: String
    let historyId: String?
    let snippet: String?
    let payload: Payload?
    let internalDate: String?
    let labelIds: [String]?
}

struct GmailFullMessageResponse: Decodable {
    struct Payload: Decodable {
        struct Part: Decodable {
            struct Body: Decodable {
                let size: Int?
                let data: String?
                let attachmentId: String?
            }
            let partId: String?
            let filename: String?
            let mimeType: String?
            let headers: [GmailMessageDetailResponse.Payload.Header]?
            let body: Body?
            let parts: [Part]?
        }
        let mimeType: String?
        let headers: [GmailMessageDetailResponse.Payload.Header]?
        let body: Part.Body?
        let parts: [Part]?
    }
    let id: String
    let threadId: String
    let historyId: String?
    let snippet: String?
    let internalDate: String?
    let labelIds: [String]?
    let payload: Payload?
}

struct GmailThreadResponse: Decodable {
    let id: String
    let messages: [GmailFullMessageResponse]?
}

struct GmailLabelsListResponse: Decodable {
    let labels: [GoogleGmailLabel]?
}
