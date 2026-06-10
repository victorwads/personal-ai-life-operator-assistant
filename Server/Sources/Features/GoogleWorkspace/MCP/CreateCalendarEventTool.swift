import Foundation

@MainActor
struct CreateCalendarEventTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GoogleCalendarService

    init(serviceProvider: @escaping @MainActor () -> GoogleCalendarService) {
        self.serviceProvider = serviceProvider
    }

    let name = "create_calendar_event"
    let icon = "calendar.badge.plus"
    let description = "Creates a new calendar event on the primary calendar."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "title": .object(["type": .string("string"), "description": .string("Title / Summary of the event.")]),
            "description": .object(["type": .string("string"), "description": .string("Optional description / details of the event.")]),
            "location": .object(["type": .string("string"), "description": .string("Optional location of the event.")]),
            "startDateTime": .object(["type": .string("string"), "description": .string("Start date-time in ISO-8601 format (e.g. '2026-06-15T09:00:00Z').")]),
            "endDateTime": .object(["type": .string("string"), "description": .string("End date-time in ISO-8601 format (e.g. '2026-06-15T10:00:00Z').")]),
            "attendees": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
                "description": .string("Optional list of attendee email addresses.")
            ])
        ]),
        "required": .array([.string("title"), .string("startDateTime"), .string("endDateTime")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "title", value: .string("Sync Meeting")),
        .init(name: "startDateTime", value: .string("2026-06-15T14:00:00-03:00")),
        .init(name: "endDateTime", value: .string("2026-06-15T15:00:00-03:00")),
        .init(name: "attendees", value: .array([.string("colleague@example.com")]))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let title = try MCPSupport.string("title", from: call)
        let description = MCPSupport.optionalString("description", from: call)
        let location = MCPSupport.optionalString("location", from: call)
        let startDateTime = try MCPSupport.string("startDateTime", from: call)
        let endDateTime = try MCPSupport.string("endDateTime", from: call)

        var attendeesList: [String]? = nil
        if let attsVal = call.arguments["attendees"] {
            if case .array(let items) = attsVal {
                attendeesList = items.compactMap { $0.stringValue }
            }
        }

        let service = serviceProvider()
        let event = try await service.createCalendarEvent(
            title: title,
            description: description,
            location: location,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            attendees: attendeesList
        )

        return try encodeEvent(event)
    }

    private func encodeEvent(_ event: GoogleCalendarEvent) throws -> MCPJSONValue {
        let data = try JSONEncoder().encode(event)
        return try JSONDecoder().decode(MCPJSONValue.self, from: data)
    }
}
