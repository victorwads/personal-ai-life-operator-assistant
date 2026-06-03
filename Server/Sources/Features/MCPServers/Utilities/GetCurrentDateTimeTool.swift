import Foundation

struct GetCurrentDateTimeTool: MCPToolDefinition {
    let name = "get_current_datetime"
    let icon = "calendar"
    let description = "Returns the current date and time details for runtime-aware assistant decisions."
    let group = "utilities"
    let inputSchema: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])
    let traits: [MCPToolTrait] = [.readOnly]

    func execute(
        _ call: MCPToolCall,
        context _: MCPServerContext
    ) async throws -> MCPJSONValue {
        let now = Date()
        let iso8601Formatter = ISO8601DateFormatter()
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        localFormatter.timeZone = .current
        localFormatter.locale = Locale.current

        return .object([
            "iso8601": .string(iso8601Formatter.string(from: now)),
            "timestamp": .int(Int(now.timeIntervalSince1970)),
            "timezone": .string(TimeZone.current.identifier),
            "localDescription": .string(localFormatter.string(from: now))
        ])
    }
}
