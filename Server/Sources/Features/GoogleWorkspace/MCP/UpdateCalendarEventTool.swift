import Foundation

@MainActor
struct UpdateCalendarEventTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GoogleCalendarService

    init(serviceProvider: @escaping @MainActor () -> GoogleCalendarService) {
        self.serviceProvider = serviceProvider
    }

    let name = "update_calendar_event"
    let icon = "calendar.badge.clock"
    let description = "Updates fields of an existing calendar event on the primary calendar (supports partial updates)."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "eventId": .object(["type": .string("string"), "description": .string("The ID of the event to update.")]),
            "title": .object(["type": .string("string"), "description": .string("Optional updated title.")]),
            "description": .object(["type": .string("string"), "description": .string("Optional updated description.")]),
            "location": .object(["type": .string("string"), "description": .string("Optional updated location.")]),
            "startDateTime": .object(["type": .string("string"), "description": .string("Optional updated start date-time in ISO-8601 format.")]),
            "endDateTime": .object(["type": .string("string"), "description": .string("Optional updated end date-time in ISO-8601 format.")]),
            "attendees": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
                "description": .string("Optional updated list of attendee email addresses.")
            ]),
            "recurrence": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
                "description": .string("Optional updated recurrence rules list (e.g. ['RRULE:FREQ=DAILY;COUNT=2']).")
            ]),
            "status": .object(["type": .string("string"), "description": .string("Optional updated status (e.g. 'confirmed', 'tentative', 'cancelled').")])
        ]),
        "required": .array([.string("eventId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "eventId", value: .string("event-123")),
        .init(name: "title", value: .string("Updated Sync Meeting"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let eventId = try MCPSupport.string("eventId", from: call)
        let title = MCPSupport.optionalString("title", from: call)
        let description = MCPSupport.optionalString("description", from: call)
        let location = MCPSupport.optionalString("location", from: call)
        let startDateTime = MCPSupport.optionalString("startDateTime", from: call)
        let endDateTime = MCPSupport.optionalString("endDateTime", from: call)
        let status = MCPSupport.optionalString("status", from: call)

        var attendeesList: [String]? = nil
        if let attsVal = call.arguments["attendees"] {
            if case .array(let items) = attsVal {
                attendeesList = items.compactMap { $0.stringValue }
            }
        }

        var recurrenceList: [String]? = nil
        if let recVal = call.arguments["recurrence"] {
            if case .array(let items) = recVal {
                recurrenceList = items.compactMap { $0.stringValue }
            }
        }

        let service = serviceProvider()
        let event = try await service.updateCalendarEvent(
            eventId: eventId,
            title: title,
            description: description,
            location: location,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            attendees: attendeesList,
            recurrence: recurrenceList,
            status: status
        )

        return try encodeEvent(event)
    }

    private func encodeEvent(_ event: GoogleCalendarEvent) throws -> MCPJSONValue {
        let data = try JSONEncoder().encode(event)
        return try JSONDecoder().decode(MCPJSONValue.self, from: data)
    }
}
