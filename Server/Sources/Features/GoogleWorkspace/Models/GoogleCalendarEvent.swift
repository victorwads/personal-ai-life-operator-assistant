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
    let recurrence: [String]?
    let conferenceData: GoogleConferenceData?
    let status: String?
}

struct GoogleConferenceData: Codable, Equatable, Sendable {
    struct EntryPoint: Codable, Equatable, Sendable {
        let entryPointType: String?
        let uri: String?
        let label: String?
        let pin: String?
        let accessCode: String?
        let password: String?
    }
    struct ConferenceSolution: Codable, Equatable, Sendable {
        struct Key: Codable, Equatable, Sendable {
            let type: String?
        }
        let key: Key?
        let name: String?
        let iconUri: String?
    }
    
    let conferenceId: String?
    let conferenceSolution: ConferenceSolution?
    let entryPoints: [EntryPoint]?
    let signature: String?
    let notes: String?
}
