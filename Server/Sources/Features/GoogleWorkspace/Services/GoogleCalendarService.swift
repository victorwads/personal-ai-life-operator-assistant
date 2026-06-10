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

    func listCalendars() async throws -> [GoogleCalendarListEntry] {
        let url = "https://www.googleapis.com/calendar/v3/users/me/calendarList"
        let response: GoogleCalendarListResponse = try await httpClient.get(url)
        return response.items ?? []
    }

    func createCalendarEvent(
        title: String,
        description: String?,
        location: String?,
        startDateTime: String,
        endDateTime: String,
        attendees: [String]?
    ) async throws -> GoogleCalendarEvent {
        let startPoint = GoogleCalendarEvent.DateTimePoint(dateTime: startDateTime, date: nil)
        let endPoint = GoogleCalendarEvent.DateTimePoint(dateTime: endDateTime, date: nil)
        let mappedAttendees = attendees?.map { GoogleCalendarEvent.Attendee(email: $0, displayName: nil, responseStatus: nil) }

        let payload = GoogleCalendarEventCreatePayload(
            summary: title,
            description: description,
            location: location,
            start: startPoint,
            end: endPoint,
            attendees: mappedAttendees
        )

        let url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        let queryItems = [URLQueryItem(name: "sendUpdates", value: "none")]

        return try await httpClient.post(url, body: payload, queryItems: queryItems)
    }

    func updateCalendarEvent(
        eventId: String,
        title: String?,
        description: String?,
        location: String?,
        startDateTime: String?,
        endDateTime: String?,
        attendees: [String]?,
        recurrence: [String]?,
        status: String?
    ) async throws -> GoogleCalendarEvent {
        var startPoint: GoogleCalendarEvent.DateTimePoint? = nil
        if let startDateTime = startDateTime {
            startPoint = GoogleCalendarEvent.DateTimePoint(dateTime: startDateTime, date: nil)
        }
        var endPoint: GoogleCalendarEvent.DateTimePoint? = nil
        if let endDateTime = endDateTime {
            endPoint = GoogleCalendarEvent.DateTimePoint(dateTime: endDateTime, date: nil)
        }
        let mappedAttendees = attendees?.map { GoogleCalendarEvent.Attendee(email: $0, displayName: nil, responseStatus: nil) }

        let payload = GoogleCalendarEventUpdatePayload(
            summary: title,
            description: description,
            location: location,
            start: startPoint,
            end: endPoint,
            attendees: mappedAttendees,
            recurrence: recurrence,
            status: status
        )

        let url = "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(eventId)"
        let queryItems = [URLQueryItem(name: "sendUpdates", value: "none")]

        return try await httpClient.patch(url, body: payload, queryItems: queryItems)
    }

    func deleteCalendarEvent(eventId: String) async throws {
        let url = "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(eventId)"
        let _: GoogleEmptyResponse = try await httpClient.delete(url)
    }
}

// MARK: - Payloads & Response Helper Models

struct GoogleCalendarListEntry: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let summary: String?
    let primary: Bool?
    let accessRole: String?
}

struct GoogleCalendarListResponse: Decodable {
    let items: [GoogleCalendarListEntry]?
}

struct GoogleCalendarEventsResponse: Decodable {
    let items: [GoogleCalendarEvent]?
}

struct GoogleCalendarEventCreatePayload: Encodable {
    let summary: String
    let description: String?
    let location: String?
    let start: GoogleCalendarEvent.DateTimePoint
    let end: GoogleCalendarEvent.DateTimePoint
    let attendees: [GoogleCalendarEvent.Attendee]?
}

struct GoogleCalendarEventUpdatePayload: Encodable {
    let summary: String?
    let description: String?
    let location: String?
    let start: GoogleCalendarEvent.DateTimePoint?
    let end: GoogleCalendarEvent.DateTimePoint?
    let attendees: [GoogleCalendarEvent.Attendee]?
    let recurrence: [String]?
    let status: String?
}
