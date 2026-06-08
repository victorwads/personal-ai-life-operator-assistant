import SwiftUI

struct IssueActionsMenu: View {
    let status: IssueStatus
    let onResolve: () -> Void
    let onCancel: () -> Void
    let onSuspend: () -> Void
    let onReactivate: () -> Void

    var body: some View {
        Menu {
            switch status {
            case .pending:
                Button("Resolve", systemImage: "checkmark.seal", action: onResolve)
                Button("Cancel", systemImage: "xmark.circle", role: .destructive, action: onCancel)
                Button("Suspend", systemImage: "pause.circle", action: onSuspend)
            case .suspended:
                Button("Reactivate", systemImage: "arrow.uturn.backward.circle", action: onReactivate)
                Button("Resolve", systemImage: "checkmark.seal", action: onResolve)
                Button("Cancel", systemImage: "xmark.circle", role: .destructive, action: onCancel)
            case .resolved, .cancelled:
                Button("Reactivate", systemImage: "arrow.uturn.backward.circle", action: onReactivate)
            }
        } label: {
            Label("Actions", systemImage: "ellipsis.circle")
        }
        .help("Manual status corrections")
    }
}
