import Foundation

struct GetCurrentDateTool: MCPToolHandler {
    static let definition = MCPToolDefinition(
        name: "get_current_date",
        icon: "calendar",
        description: "Returns today's local date and current timestamp so the assistant can reference the present day.",
        inputSchema: [
            "type": .string("object"),
            "properties": .object([:])
        ],
        exampleParameters: [],
        traits: [.readOnly]
    )

    static func handle(_ call: MCPToolCall, context: MCPServerContext) async -> Result<JSONValue, Error> {
        let now = Date()
        let timeZone = TimeZone.autoupdatingCurrent

        let isoTimestampFormatter = ISO8601DateFormatter()
        isoTimestampFormatter.timeZone = timeZone
        isoTimestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoDateFormatter = DateFormatter()
        isoDateFormatter.locale = Locale.autoupdatingCurrent
        isoDateFormatter.timeZone = timeZone
        isoDateFormatter.dateFormat = "yyyy-MM-dd"

        let displayDateFormatter = DateFormatter()
        displayDateFormatter.locale = Locale.autoupdatingCurrent
        displayDateFormatter.timeZone = timeZone
        displayDateFormatter.dateStyle = .full
        displayDateFormatter.timeStyle = .none

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale.autoupdatingCurrent
        weekdayFormatter.timeZone = timeZone
        weekdayFormatter.dateFormat = "EEEE"

        return .success(.object([
            "date": .string(isoDateFormatter.string(from: now)),
            "displayDate": .string(displayDateFormatter.string(from: now)),
            "isoDateTime": .string(isoTimestampFormatter.string(from: now)),
            "weekday": .string(weekdayFormatter.string(from: now)),
            "timeZone": .string(timeZone.identifier)
        ]))
    }
}
