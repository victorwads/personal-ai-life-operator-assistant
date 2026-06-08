import Foundation
import SwiftUI

enum IssueDisplaySupport {
    static func statusTitle(for status: IssueStatus) -> String {
        switch status {
        case .pending:
            return "Active"
        case .suspended:
            return "Suspended"
        case .resolved:
            return "Resolved"
        case .cancelled:
            return "Cancelled"
        }
    }

    static func statusBadgeStyle(for status: IssueStatus) -> DSBadge.Style {
        switch status {
        case .pending:
            return .info
        case .suspended:
            return .warning
        case .resolved:
            return .success
        case .cancelled:
            return .danger
        }
    }

    static func priorityText(for priority: IssuePriority) -> String {
        switch priority {
        case .veryLow:
            return "1 Very Low"
        case .low:
            return "2 Low"
        case .medium:
            return "3 Medium"
        case .high:
            return "4 High"
        case .urgent:
            return "5 Urgent"
        }
    }

    static func priorityBadgeStyle(for priority: IssuePriority) -> DSBadge.Style {
        switch priority.rawValue {
        case 1, 2:
            return .neutral
        case 3:
            return .info
        case 4:
            return .warning
        default:
            return .danger
        }
    }

    static func formattedSuspendUntil(_ suspendUntil: Date?) -> String {
        guard let suspendUntil else {
            return "Not scheduled"
        }

        return suspendUntil.formatted(date: .abbreviated, time: .shortened)
    }

    static func formattedTimelineKind(_ kind: String) -> String {
        let spaced = kind
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: "([a-z0-9])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return spaced.isEmpty ? "Timeline Item" : spaced.localizedCapitalized
    }
}
