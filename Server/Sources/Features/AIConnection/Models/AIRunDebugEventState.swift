import Foundation

struct AIRunDebugEventState: Identifiable {
    let id = UUID()
    let kind: String
    let summary: String
    let timestamp: Date

    var line: String {
        "\(Self.timestampFormatter.string(from: timestamp)) [\(kind)] \(summary)"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
