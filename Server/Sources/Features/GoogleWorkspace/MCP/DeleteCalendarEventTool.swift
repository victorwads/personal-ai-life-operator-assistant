import Foundation

@MainActor
struct DeleteCalendarEventTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GoogleCalendarService

    init(serviceProvider: @escaping @MainActor () -> GoogleCalendarService) {
        self.serviceProvider = serviceProvider
    }

    let name = "delete_calendar_event"
    let icon = "calendar.badge.minus"
    let description = "Deletes a calendar event by ID from the primary calendar."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "eventId": .object(["type": .string("string"), "description": .string("The ID of the event to delete.")])
        ]),
        "required": .array([.string("eventId")])
    ])

    let exampleParameters: [MCPToolExampleParameter] = [
        .init(name: "eventId", value: .string("event-123"))
    ]

    let traits: [MCPToolTrait] = []

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let eventId = try MCPSupport.string("eventId", from: call)

        let service = serviceProvider()
        try await service.deleteCalendarEvent(eventId: eventId)

        return .string("Successfully deleted calendar event with ID: \(eventId).")
    }
}
