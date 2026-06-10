import Foundation

@MainActor
struct ListCalendarsTool: MCPToolDefinition {
    private let serviceProvider: @MainActor () -> GoogleCalendarService

    init(serviceProvider: @escaping @MainActor () -> GoogleCalendarService) {
        self.serviceProvider = serviceProvider
    }

    let name = "list_calendars"
    let icon = "calendar"
    let description = "Lists all calendars in the authenticated user's calendar list."
    let group = "googleWorkspace"

    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])

    let exampleParameters: [MCPToolExampleParameter] = []

    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let service = serviceProvider()
        let calendars = try await service.listCalendars()

        guard !calendars.isEmpty else {
            return .string("No calendars found.")
        }

        var lines = ["<calendars count=\"\(calendars.count)\">"]
        for cal in calendars {
            let primaryStr = cal.primary == true ? "true" : "false"
            lines.append("  <calendar id=\"\(cal.id)\" primary=\"\(primaryStr)\" accessRole=\"\(cal.accessRole ?? "none")\">")
            lines.append("    <summary>\(cal.summary ?? "(No Title)")</summary>")
            lines.append("  </calendar>")
        }
        lines.append("</calendars>")

        return .string(lines.joined(separator: "\n"))
    }
}
