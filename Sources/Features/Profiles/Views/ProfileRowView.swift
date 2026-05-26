import SwiftUI

struct ProfileRowView: View {
    let profile: Profile
    let runtimeState: ProfileRuntimeState
    let windowState: ProfileWindowState
    let onToggleAutoStart: (Bool) -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onShowWindow: () -> Void
    let onHideWindow: () -> Void

    @State private var isRenaming = false
    @State private var proposedName = ""
    @FocusState private var isRenameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                titleView

                Spacer(minLength: 0)

                ProfileStatusBadgeView(runtimeState: runtimeState)
            }

            HStack(spacing: 14) {
                Text("Port: \(profile.mcpPort)")
                    .foregroundStyle(.secondary)

                Toggle("Auto Start", isOn: Binding(
                    get: { profile.autoStart },
                    set: { onToggleAutoStart($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                Text(profile.autoStart ? "Auto Start: On" : "Auto Start: Off")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Spacer(minLength: 0)

                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help("Delete this profile")
                    .accessibilityLabel("Delete profile")
                    .accessibilityHint("Deletes \(profile.name)")
            }

            ProfileActionsView(
                runtimeState: runtimeState,
                windowState: windowState,
                onStart: onStart,
                onStop: onStop,
                onShowWindow: onShowWindow,
                onHideWindow: onHideWindow
            )
        }
        .padding(12)
        .background(.quaternary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var titleView: some View {
        if isRenaming {
            TextField("Profile name", text: $proposedName)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
                .frame(maxWidth: 320)
                .focused($isRenameFieldFocused)
                .onSubmit { commitRename() }
                .onAppear {
                    proposedName = profile.name
                    isRenameFieldFocused = true
                }
                .help("Press Return to save the new profile name")
                .accessibilityLabel("Profile name")
                .accessibilityHint("Press Return to save")
        } else {
            Text(profile.name)
                .font(.headline)
                .help("Double click to rename")
                .accessibilityLabel("Profile name: \(profile.name)")
                .accessibilityHint("Double click to rename")
                .onTapGesture(count: 2) {
                    proposedName = profile.name
                    isRenaming = true
                }
        }
    }

    private func commitRename() {
        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if trimmedName != profile.name {
            onRename(trimmedName)
        }
        isRenaming = false
    }
}
