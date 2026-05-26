import Combine
import Foundation

@MainActor
final class ProfilesController: ObservableObject {
    let profilesViewModel: ProfilesHomeViewModel
    let runtimeController: ProfileRuntimeController

    var onProfilesChanged: (([Profile]) -> Void)?

    private var cancellables: Set<AnyCancellable> = []

    init(
        profileRepository: ProfileRepository,
        windowManager: ProfileWindowManaging
    ) {
        self.profilesViewModel = ProfilesHomeViewModel(repository: profileRepository)
        self.runtimeController = ProfileRuntimeController(
            registry: ProfileRuntimeRegistry(),
            windowManager: windowManager
        )

        profilesViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        profilesViewModel.onProfilesChanged = { [weak self] profiles in
            Task { @MainActor in
                self?.onProfilesChanged?(profiles)
            }
        }
    }

    var profiles: [Profile] {
        profilesViewModel.profiles
    }

    var isLoading: Bool {
        profilesViewModel.isLoading
    }

    var errorMessage: String? {
        profilesViewModel.errorMessage
    }

    var profileCreationConflictId: String? {
        profilesViewModel.profileCreationConflictId
    }

    var profileDisplayStates: [ProfileDisplayState] {
        profiles.map { runtimeController.displayState(for: $0) }
    }

    func setAuthSession(_ session: AuthSession?) {
        profilesViewModel.setAuthSession(session)
    }

    func loadProfiles() {
        profilesViewModel.loadProfiles()
    }

    func reset() {
        profilesViewModel.reset()
        objectWillChange.send()
    }

    func createProfile(profileId: String? = nil) {
        profilesViewModel.createProfile(profileId: profileId)
    }

    func clearProfileCreationConflict() {
        profilesViewModel.clearProfileCreationConflict()
    }

    func renameProfile(profileId: String, name: String) {
        profilesViewModel.renameProfile(profileId: profileId, name: name)
    }

    func deleteProfile(profileId: String) {
        profilesViewModel.deleteProfile(profileId: profileId)
    }

    func toggleAutoStart(profileId: String, enabled: Bool) {
        profilesViewModel.toggleAutoStart(profileId: profileId, enabled: enabled)
    }

    func startAutoStartProfiles() async {
        for profile in profiles where profile.autoStart {
            await startProfile(profileId: profile.id ?? "")
        }
    }

    func startProfile(profileId: String) async {
        guard let profile = profile(for: profileId) else { return }
        await runtimeController.startProfile(profile)
        objectWillChange.send()
    }

    func stopProfile(profileId: String) async {
        runtimeController.hideProfileWindow(profileId: profileId)
        await runtimeController.stopProfile(profileId: profileId)
        objectWillChange.send()
    }

    func openProfileWindow(profileId: String) async {
        guard let profile = profile(for: profileId) else { return }
        await runtimeController.openProfileWindow(profile)
        objectWillChange.send()
    }

    func hideProfileWindow(profileId: String) {
        runtimeController.hideProfileWindow(profileId: profileId)
        objectWillChange.send()
    }

    func stopAllRunningProfiles() async {
        await runtimeController.stopAllProfiles()
        objectWillChange.send()
    }

    func displayState(for profile: Profile) -> ProfileDisplayState {
        runtimeController.displayState(for: profile)
    }

    private func profile(for profileId: String) -> Profile? {
        profiles.first { $0.id == profileId }
    }
}
