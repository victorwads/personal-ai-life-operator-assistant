import Foundation

@MainActor
final class GoogleCalendarService {
    private let httpClient: GoogleWorkspaceHTTPClient

    init(httpClient: GoogleWorkspaceHTTPClient) {
        self.httpClient = httpClient
    }

    func listUpcomingEvents(calendarId: String = "primary", maxResults: Int = 10) async throws -> [GoogleCalendarEvent] {
        let timeMinStr = ISO8601DateFormatter().string(from: Date())
        let queryItems = [
            URLQueryItem(name: "timeMin", value: timeMinStr),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        let url = "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events"
        let response: GoogleCalendarEventsResponse = try await httpClient.get(url, queryItems: queryItems)

        return response.items ?? []
    }
}

struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarEvent]?
}
