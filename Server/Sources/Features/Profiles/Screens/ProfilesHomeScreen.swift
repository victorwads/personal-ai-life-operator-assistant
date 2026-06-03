import SwiftUI

public struct ProfilesHomeScreen: View {
    @ObservedObject private var profilesController: ProfilesController

    @State private var manualProfileId = ""

    init(profilesController: ProfilesController) {
        _profilesController = ObservedObject(wrappedValue: profilesController)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let errorMessage = profilesController.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding(.vertical, 6)
            }

            if profilesController.isLoading {
                ProgressView()
                    .padding(.vertical, 16)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(profilesController.profileDisplayStates) { row in
                        ProfileRowView(
                            profile: row.profile,
                            runtimeState: row.runtimeState,
                            windowState: row.windowState,
                            onToggleAutoStart: { enabled in
                                if let profileId = row.profile.id {
                                    profilesController.toggleAutoStart(profileId: profileId, enabled: enabled)
                                }
                            },
                            onRename: { name in
                                if let profileId = row.profile.id {
                                    profilesController.renameProfile(profileId: profileId, name: name)
                                }
                            },
                            onDelete: {
                                if let profileId = row.profile.id {
                                    profilesController.deleteProfile(profileId: profileId)
                                }
                            },
                            onStart: {
                                if let profileId = row.profile.id {
                                    Task { @MainActor in
                                        await profilesController.startProfile(profileId: profileId)
                                    }
                                }
                            },
                            onStop: {
                                if let profileId = row.profile.id {
                                    Task { @MainActor in
                                        await profilesController.stopProfile(profileId: profileId)
                                    }
                                }
                            },
                            onShowWindow: {
                                if let profileId = row.profile.id {
                                    Task { @MainActor in
                                        await profilesController.openProfileWindow(profileId: profileId)
                                    }
                                }
                            },
                            onHideWindow: {
                                if let profileId = row.profile.id {
                                    profilesController.hideProfileWindow(profileId: profileId)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 980, minHeight: 680, alignment: .topLeading)
        .sheet(
            isPresented: Binding(
                get: { profilesController.profileCreationConflictId != nil },
                set: { isPresented in
                    if !isPresented {
                        manualProfileId = ""
                        profilesController.clearProfileCreationConflict()
                    }
                }
            )
        ) {
            createProfileConflictSheet(existingProfileId: profilesController.profileCreationConflictId ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Profiles")
                    .font(.largeTitle.weight(.semibold))
                Text("Manage profiles, runtime state, windows, and tray behavior.")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("Refresh") { profilesController.loadProfiles() }
                .buttonStyle(.bordered)

            Button("New Profile") { profilesController.createProfile() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func createProfileConflictSheet(existingProfileId: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile Already Exists")
                .font(.title2.weight(.semibold))

            Text("A profile already exists for Firebase user ID \(existingProfileId). Enter another Firebase user ID to create a profile manually.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Firebase user ID", text: $manualProfileId)
                .textFieldStyle(.roundedBorder)
                .frame(width: 420)

            HStack {
                Spacer()

                Button("Cancel") {
                    manualProfileId = ""
                    profilesController.clearProfileCreationConflict()
                }

                Button("Create") {
                    profilesController.createProfile(profileId: manualProfileId)
                    manualProfileId = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(manualProfileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
