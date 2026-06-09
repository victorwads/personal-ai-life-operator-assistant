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
            threadId: response.threadId,
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
    let snippet: String?
    let payload: Payload?
    let internalDate: String?
    let labelIds: [String]?
}
