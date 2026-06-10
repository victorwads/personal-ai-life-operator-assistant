import Foundation

struct GoogleCalendarEvent: Codable, Equatable, Sendable, Identifiable {
    struct DateTimePoint: Codable, Equatable, Sendable {
        let dateTime: String?
        let date: String?
    }

    struct Attendee: Codable, Equatable, Sendable {
        let email: String?
        let displayName: String?
        let responseStatus: String?
    }

    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let htmlLink: String?
    let start: DateTimePoint
    let end: DateTimePoint
    let attendees: [Attendee]?
}
