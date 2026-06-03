import Foundation

enum ProfileRuntimeServiceStatusFormatting {
    static func stateLabel(for state: ProfileRuntimeServiceState) -> String {
        switch state {
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting"
        case .running:
            return "Running"
        case .stopping:
            return "Stopping"
        case .failed:
            return "Failed"
        }
    }

    static func detail(for state: ProfileRuntimeServiceState, fallback: String? = nil) -> String? {
        if case .failed(let message) = state {
            return message
        }
        return fallback
    }

    static func actionTitle(for state: ProfileRuntimeServiceState) -> String? {
        switch state {
        case .stopped, .failed:
            return "Start"
        case .running, .starting:
            return "Stop"
        case .stopping:
            return nil
        }
    }
}
