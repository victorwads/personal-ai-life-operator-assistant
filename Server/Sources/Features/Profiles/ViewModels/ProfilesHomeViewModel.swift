import Foundation

@MainActor
final class ProfilesHomeViewModel: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var profileCreationConflictId: String?

    var onProfilesChanged: (([Profile]) -> Void)?

    private let repository: ProfileRepository
    private var listenerToken: FirestoreListenerToken?
    private var authUid: String?

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func setAuthSession(_ session: AuthSession?) {
        authUid = session?.user.uid
    }

    func reset() {
        listenerToken?.cancel()
        listenerToken = nil
        profiles = []
        errorMessage = nil
        profileCreationConflictId = nil
        isLoading = false
        authUid = nil
        onProfilesChanged?(profiles)
    }

    func refresh() {
        loadProfiles()
    }

    func loadProfiles() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let items = try await repository.listProfiles()
                let sorted = items.sorted { $0.name < $1.name }
                profiles = sorted
                isLoading = false
                ensureObservation()
                onProfilesChanged?(sorted)
            } catch {
                errorMessage = (error as NSError).localizedDescription
                isLoading = false
                onProfilesChanged?(profiles)
            }
        }
    }

    func createProfile(profileId requestedProfileId: String? = nil) {
        Task {
            do {
                guard let defaultProfileId = authUid?.trimmingCharacters(in: .whitespacesAndNewlines), !defaultProfileId.isEmpty else {
                    errorMessage = "You need a Firebase Authentication UID to create a profile."
                    return
                }

                let profileId = (requestedProfileId ?? defaultProfileId).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !profileId.isEmpty else {
                    errorMessage = "Profile ID cannot be empty."
                    return
                }

                if try await repository.getProfile(id: profileId) != nil {
                    if requestedProfileId == nil {
                        profileCreationConflictId = profileId
                    } else {
                        errorMessage = "A profile already exists with ID \(profileId)."
                    }
                    return
                }

                let profile = Profile(
                    id: profileId,
                    ownerUid: profileId,
                    name: "Profile \(profileId.prefix(8))",
                    mcpPort: nextSuggestedPort(),
                    autoStart: false
                )

                _ = try await repository.saveProfile(profile)
                profileCreationConflictId = nil
                refresh()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    func clearProfileCreationConflict() {
        profileCreationConflictId = nil
    }

    func renameProfile(profileId: String, name: String) {
        guard var updated = profiles.first(where: { $0.id == profileId }) else { return }
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.name.isEmpty else { return }

        Task {
            do {
                _ = try await repository.saveProfile(updated)
                refresh()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    func toggleAutoStart(profileId: String, enabled: Bool) {
        guard var updated = profiles.first(where: { $0.id == profileId }) else { return }
        updated.autoStart = enabled
        Task {
            do {
                _ = try await repository.saveProfile(updated)
                refresh()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    func deleteProfile(profileId: String) {
        Task {
            do {
                try await repository.deleteProfile(id: profileId)
                refresh()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    // MARK: - Private

    private func ensureObservation() {
        guard listenerToken == nil else { return }
        listenerToken = repository.observeProfiles { [weak self] profiles in
            Task { @MainActor in
                let sorted = profiles.sorted { $0.name < $1.name }
                self?.profiles = sorted
                self?.onProfilesChanged?(sorted)
            }
        }
    }

    private func nextSuggestedPort() -> Int {
        let usedPorts = Set(profiles.map { $0.mcpPort })
        var port = 8080
        while usedPorts.contains(port) { port += 1 }
        return port
    }

}
