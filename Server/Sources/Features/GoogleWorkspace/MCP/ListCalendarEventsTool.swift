import Foundation

@MainActor
struct ListCalendarEventsTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GoogleCalendarService

    init(serviceProvider: @escaping @MainActor () -> GoogleCalendarService) {
        self.serviceProvider = serviceProvider
    }

    let name = "list_calendar_events"
    let icon = "calendar"
    let description = "Lists upcoming events from the user's primary or specific Google Calendar."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "calendarId": .object([
                "type": .string("string"),
                "description": .string("Optional ID of the calendar to query (defaults to 'primary').")
            ]),
            "maxResults": .object([
                "type": .string("integer"),
                "description": .string("Optional maximum number of events to return (default 10).")
            ])
        ])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "calendarId", value: .string("primary")),
        .init(name: "maxResults", value: .integer(5))
    ]

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let calendarId = MCPSupport.optionalString("calendarId", from: call) ?? "primary"
        let maxResults = MCPSupport.optionalInt("maxResults", from: call) ?? 10

        let service = serviceProvider()
        let events = try await service.listUpcomingEvents(calendarId: calendarId, maxResults: maxResults)

        guard !events.isEmpty else {
            return .string("No upcoming events found.")
        }

        var lines: [String] = ["<events count=\"\(events.count)\">"]
        for event in events {
            lines.append("  <event id=\"\(event.id)\">")
            if let summary = event.summary {
                lines.append("    <summary>\(summary)</summary>")
            }
            
            // Format start and end date/dateTime
            let startText = event.start.dateTime ?? event.start.date ?? ""
            let endText = event.end.dateTime ?? event.end.date ?? ""
            lines.append("    <start>\(startText)</start>")
            lines.append("    <end>\(endText)</end>")

            if let location = event.location {
                lines.append("    <location>\(location)</location>")
            }
            if let description = event.description {
                lines.append("    <description>\(description)</description>")
            }
            if let htmlLink = event.htmlLink {
                lines.append("    <htmlLink>\(htmlLink)</htmlLink>")
            }
            
            if let attendees = event.attendees, !attendees.isEmpty {
                lines.append("    <attendees>")
                for attendee in attendees {
                    let email = attendee.email ?? "unknown"
                    let response = attendee.responseStatus ?? "needsAction"
                    lines.append("      <attendee email=\"\(email)\" status=\"\(response)\" />")
                }
                lines.append("    </attendees>")
            }
            lines.append("  </event>")
        }
        lines.append("</events>")

        return .string(lines.joined(separator: "\n"))
    }
}
