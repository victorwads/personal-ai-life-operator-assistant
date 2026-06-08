import SwiftUI

enum IssueStatusTransitionMode: String, CaseIterable, Identifiable, Sendable {
    case resolve
    case cancel
    case suspend
    case reactivate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resolve:
            return "Resolve Issue"
        case .cancel:
            return "Cancel Issue"
        case .suspend:
            return "Suspend Issue"
        case .reactivate:
            return "Reactivate Issue"
        }
    }

    var submitTitle: String {
        switch self {
        case .resolve:
            return "Resolve"
        case .cancel:
            return "Cancel Issue"
        case .suspend:
            return "Suspend"
        case .reactivate:
            return "Reactivate"
        }
    }

    var reasonLabel: String {
        switch self {
        case .suspend:
            return "Reason (optional)"
        case .reactivate:
            return "Why should this issue become active again?"
        case .resolve, .cancel:
            return "Reason"
        }
    }

    var reasonPlaceholder: String {
        switch self {
        case .suspend:
            return "Optional context for the audit trail"
        case .reactivate:
            return "Explain why the issue should be active again"
        case .resolve:
            return "Why is this issue resolved?"
        case .cancel:
            return "Why is this issue cancelled?"
        }
    }

    var reasonRequired: Bool {
        self != .suspend
    }

    var requiresSuspendUntil: Bool {
        self == .suspend
    }
}

struct IssueStatusTransitionRequest: Identifiable, Sendable {
    let issueId: String
    let issueTitle: String
    let currentStatus: IssueStatus
    let mode: IssueStatusTransitionMode

    var id: String {
        "\(issueId)-\(mode.rawValue)"
    }
}

struct IssueStatusTransitionSheet: View {
    let request: IssueStatusTransitionRequest
    let onSubmit: (IssueStatusTransitionRequest, String?, Date?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var suspendUntil = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(request.issueTitle)
                            .font(.headline)
                        Text("Current status: \(IssueDisplaySupport.statusTitle(for: request.currentStatus))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(request.mode.reasonLabel) {
                    TextField(request.mode.reasonPlaceholder, text: $reason)
                }

                if request.mode.requiresSuspendUntil {
                    Section("Suspend Until") {
                        DatePicker(
                            "Suspend Until",
                            selection: $suspendUntil,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(request.mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(request.mode.submitTitle) {
                        Task {
                            await submit()
                        }
                    }
                    .disabled(isSubmitting || !isInputValid)
                }
            }
        }
        .frame(minWidth: 460, minHeight: request.mode.requiresSuspendUntil ? 360 : 300)
        .onAppear {
            if request.mode.requiresSuspendUntil && suspendUntil <= Date() {
                suspendUntil = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            }
        }
    }

    private var isInputValid: Bool {
        switch request.mode {
        case .suspend:
            return suspendUntil > Date()
        case .resolve, .cancel, .reactivate:
            return !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if request.mode.reasonRequired && trimmedReason.isEmpty {
            errorMessage = "Reason is required."
            return
        }

        if request.mode.requiresSuspendUntil && suspendUntil <= Date() {
            errorMessage = "Suspend until must be in the future."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await onSubmit(
                request,
                request.mode.requiresSuspendUntil ? (trimmedReason.isEmpty ? nil : trimmedReason) : trimmedReason,
                request.mode.requiresSuspendUntil ? suspendUntil : nil
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
