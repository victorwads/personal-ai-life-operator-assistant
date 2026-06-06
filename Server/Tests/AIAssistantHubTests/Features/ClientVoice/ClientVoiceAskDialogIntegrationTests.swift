import XCTest
@testable import AIAssistantHub

@MainActor
final class ClientVoiceAskDialogIntegrationTests: XCTestCase {
    func testOpeningAskDialogForFirstEmulatorProfileDoesNotCrashWindowLayout() async throws {
        FirebaseAppConfigurator.configure()

        let profileRepository = FirestoreProfileRepository()
        let profiles = try await profileRepository.listProfiles().sorted { $0.name < $1.name }
        guard let profile = profiles.first, let profileId = profile.id, !profileId.isEmpty else {
            throw XCTSkip("No profiles were found in the Firebase Emulator store.")
        }

        let visibilityTracker = WindowVisibilityTracker()
        let dockVisibilityController = DockVisibilityController()
        let windowManager = AppWindowManager(
            visibilityTracker: visibilityTracker,
            dockVisibilityController: dockVisibilityController
        )
        let profilesController = ProfilesController(
            profileRepository: profileRepository,
            windowManager: windowManager
        )
        windowManager.configure(profilesController: profilesController)

        let runtime = ProfileRuntime(
            context: ProfileContext(profile: profile),
            windowManager: windowManager
        )
        let container = try await runtime.ensureContainer()
        let feature = container.appFeatures.feature(ClientVoiceFeature.self)

        let request: ClientInteractionRequest
        if let existingRequest = try await existingAskRequest(in: feature) {
            request = existingRequest
        } else {
            request = try await feature.repository.createRequest(
                issueId: nil,
                kind: .ask,
                status: .waitingUser,
                promptText: "Integration test prompt"
            )
        }

        feature.openAnswerDialog(for: request)
        pumpMainRunLoop(for: 1.0)

        let expectedWindowId = "profile_\(profileId)_feature_client_voice_ask_\(try requestID(from: request))"
        XCTAssertTrue(
            visibilityTracker.visibleWindowIds.contains(expectedWindowId),
            "Expected the Client Voice ask dialog window to become visible for profile \(profileId)."
        )

        windowManager.hideFeatureWindow(
            profileId: profileId,
            featureWindowId: "client_voice_ask_\(try requestID(from: request))"
        )
        await runtime.stop(flushPendingSettings: false)
    }

    private func existingAskRequest(in feature: ClientVoiceFeature) async throws -> ClientInteractionRequest? {
        let requests = try await feature.repository.listRequests()
        return requests.first {
            $0.kind == .ask && [.waitingUser, .speaking].contains($0.status) && $0.id != nil
        }
    }

    private func requestID(from request: ClientInteractionRequest) throws -> String {
        guard let requestID = request.id, !requestID.isEmpty else {
            throw XCTSkip("Client Voice request has no persisted id.")
        }

        return requestID
    }

    private func pumpMainRunLoop(for duration: TimeInterval) {
        let limit = Date().addingTimeInterval(duration)
        while Date() < limit {
            RunLoop.main.run(mode: .default, before: limit)
        }
    }
}
