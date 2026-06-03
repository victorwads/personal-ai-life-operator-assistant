import Foundation

enum AIConnectionCycleOutcome: Equatable {
    case completed
    case waitedForEvent

    func completedSummary(cycleNumber: Int) -> String {
        switch self {
        case .completed:
            return "Cycle \(cycleNumber) completed normally."
        case .waitedForEvent:
            return "Cycle \(cycleNumber) ended at the wait_for_event idle boundary."
        }
    }

    var completionReason: String {
        switch self {
        case .completed:
            return "request_finished_clearing_context"
        case .waitedForEvent:
            return "wait_for_event_clearing_context"
        }
    }
}
