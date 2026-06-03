import Foundation

enum AIConnectionNextCycleReason {
    case normalCompletion
    case recovery

    func summary(delayMilliseconds: UInt64) -> String {
        switch self {
        case .normalCompletion:
            return "Next cycle scheduled after \(delayMilliseconds)ms."
        case .recovery:
            return "Next cycle scheduled after \(delayMilliseconds)ms to recover from failure."
        }
    }
}
