import Foundation

enum AIConnectionRuntimeStatus: String, CaseIterable {
    case stopped
    case initializing
    case promptProcessing
    case reasoning
    case executingTool
    case receivingOutput
    case cycleCompleted
    case recovering
    case waitingUser
    case waitingEvent
    case paused
    case completed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .promptProcessing:
            return "Prompt Processing"
        case .executingTool:
            return "Executing Tool"
        case .receivingOutput:
            return "Receiving Output"
        case .cycleCompleted:
            return "Cycle Completed"
        case .recovering:
            return "Recovering"
        case .waitingUser:
            return "Waiting User"
        case .waitingEvent:
            return "Waiting Event"
        default:
            return rawValue.capitalized
        }
    }

    var icon: String {
        switch self {
        case .stopped:
            return "stop.circle"
        case .initializing:
            return "arrow.clockwise.circle"
        case .promptProcessing:
            return "text.append"
        case .reasoning:
            return "brain.head.profile"
        case .executingTool:
            return "wrench.and.screwdriver"
        case .receivingOutput:
            return "text.bubble"
        case .cycleCompleted:
            return "arrow.triangle.2.circlepath"
        case .recovering:
            return "arrow.clockwise"
        case .waitingUser:
            return "person.crop.circle.badge.questionmark"
        case .waitingEvent:
            return "clock.badge.exclamationmark"
        case .paused:
            return "pause.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.octagon"
        case .cancelled:
            return "xmark.circle"
        }
    }

    var isRunningLike: Bool {
        switch self {
        case .initializing,
             .promptProcessing,
             .reasoning,
             .executingTool,
             .receivingOutput,
             .cycleCompleted,
             .recovering,
             .waitingUser,
             .waitingEvent:
            return true
        case .stopped, .paused, .completed, .failed, .cancelled:
            return false
        }
    }
}
