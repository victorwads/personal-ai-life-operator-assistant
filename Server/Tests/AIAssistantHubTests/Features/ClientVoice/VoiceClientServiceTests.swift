import XCTest
@testable import AIAssistantHub

@MainActor
final class VoiceClientServiceTests: XCTestCase {
    func testStalePendingSnapshotDoesNotReplaySpeakRequestWhileSpeaking() async throws {
        let request = ClientInteractionRequest(
            id: "voice-1",
            issueId: "issue-1",
            kind: .speak,
            status: .pending,
            clientPresenceAtCreation: .present,
            promptText: "Falar uma vez",
            requestedAt: Date()
        )
        let repository = ClientInteractionRequestRepositorySpy(initialRequests: [request])
        let settings = VoiceClientSettingsWrapper(settings: SettingsStore(
            profileId: "test-profile",
            repository: SettingsRepositorySpy()
        ))
        settings.autoFocusVoiceWindow = false
        let presenceService = VoiceClientPresenceService(id: "presence", title: "Presence")
        let speechSynthesizer = VoiceSpeechSynthesizerSpy()
        let service = VoiceClientService(
            id: "voice",
            title: "Voice",
            repository: repository,
            settings: settings,
            presenceService: presenceService,
            speechSynthesizer: speechSynthesizer,
            focusHandler: {}
        )

        await service.start()
        await presenceService.start()
        await speechSynthesizer.waitForSpeakCount(1)

        repository.emitPendingRequests([request])
        speechSynthesizer.finishCurrentSpeak()

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(speechSynthesizer.spokenTexts, ["Falar uma vez"])
        XCTAssertEqual(repository.deliveredIds, ["voice-1"])
        XCTAssertEqual(repository.completedIds, ["voice-1"])
        XCTAssertTrue(service.pendingSpeakRequests.isEmpty)

        await service.stop()
    }
}

@MainActor
private final class VoiceSpeechSynthesizerSpy: VoiceSpeechSynthesizing {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var speakCountContinuations: [(Int, CheckedContinuation<Void, Never>)] = []

    private(set) var spokenTexts: [String] = [] {
        didSet {
            let currentCount = spokenTexts.count
            let ready = speakCountContinuations.filter { currentCount >= $0.0 }
            speakCountContinuations.removeAll { currentCount >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
    }

    func speak(
        _ text: String,
        language _: String,
        voiceIdentifier _: String?,
        rate _: Float,
        volume _: Float
    ) async throws {
        spokenTexts.append(text)
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForSpeakCount(_ count: Int) async {
        guard spokenTexts.count < count else { return }
        await withCheckedContinuation { continuation in
            speakCountContinuations.append((count, continuation))
        }
    }

    func finishCurrentSpeak() {
        continuations.removeFirst().resume()
    }
}

private final class ClientInteractionRequestRepositorySpy: ClientInteractionRequestRepository {
    private var requests: [ClientInteractionRequest]
    private var pendingListener: (([ClientInteractionRequest]) -> Void)?

    private(set) var deliveredIds: [String] = []
    private(set) var completedIds: [String] = []

    init(initialRequests: [ClientInteractionRequest]) {
        requests = initialRequests
    }

    func listRequests() async throws -> [ClientInteractionRequest] {
        requests
    }

    func listPendingRequests() async throws -> [ClientInteractionRequest] {
        requests.filter { $0.status == .pending }
    }

    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        listener(requests)
        return FirestoreListenerToken {}
    }

    func observePendingRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        pendingListener = listener
        listener(requests.filter { $0.status == .pending })
        return FirestoreListenerToken {}
    }

    func createRequest(
        issueId: String,
        kind: ClientInteractionKind,
        promptText: String,
        clientPresenceAtCreation: ClientPresenceState,
        source: ClientInteractionSource,
        targetDeviceId: String?,
        metadata: [String: String]
    ) async throws -> ClientInteractionRequest {
        let request = ClientInteractionRequest(
            id: UUID().uuidString,
            issueId: issueId,
            kind: kind,
            status: .pending,
            clientPresenceAtCreation: clientPresenceAtCreation,
            promptText: promptText,
            requestedAt: Date(),
            source: source,
            targetDeviceId: targetDeviceId,
            metadata: metadata
        )
        requests.append(request)
        emitPendingRequests(requests.filter { $0.status == .pending })
        return request
    }

    func updateRequest(_ request: ClientInteractionRequest) async throws -> ClientInteractionRequest {
        try replace(request)
    }

    func markDelivered(id: String) async throws -> ClientInteractionRequest {
        deliveredIds.append(id)
        return try updateStatus(id: id, status: .delivered)
    }

    func markCompleted(id: String, responseText: String?) async throws -> ClientInteractionRequest {
        completedIds.append(id)
        var request = try updateStatus(id: id, status: .completed)
        request.responseText = responseText
        return try replace(request)
    }

    func markCancelled(id: String) async throws -> ClientInteractionRequest {
        try updateStatus(id: id, status: .cancelled)
    }

    func markFailed(id: String, errorMessage: String) async throws -> ClientInteractionRequest {
        var request = try updateStatus(id: id, status: .failed)
        request.errorMessage = errorMessage
        return try replace(request)
    }

    func deleteRequest(id: String) async throws {
        requests.removeAll { $0.id == id }
        emitPendingRequests(requests.filter { $0.status == .pending })
    }

    func emitPendingRequests(_ requests: [ClientInteractionRequest]) {
        pendingListener?(requests)
    }

    @discardableResult
    private func updateStatus(id: String, status: ClientInteractionStatus) throws -> ClientInteractionRequest {
        guard let index = requests.firstIndex(where: { $0.id == id }) else {
            throw ClientInteractionRequestRepositoryError.requestNotFound(id)
        }
        requests[index].status = status
        emitPendingRequests(requests.filter { $0.status == .pending })
        return requests[index]
    }

    @discardableResult
    private func replace(_ request: ClientInteractionRequest) throws -> ClientInteractionRequest {
        guard let id = request.id, let index = requests.firstIndex(where: { $0.id == id }) else {
            throw ClientInteractionRequestRepositoryError.requestNotFound(request.id ?? "unknown")
        }
        requests[index] = request
        emitPendingRequests(requests.filter { $0.status == .pending })
        return request
    }
}

private final class SettingsRepositorySpy: SettingsRepository {
    private var scopes: [String: SettingsDocument] = [:]

    func loadScope(_ scopeName: String) async throws -> SettingsDocument {
        scopes[scopeName] ?? SettingsDocument(scopeName: scopeName, values: [:])
    }

    func loadAllScopes() async throws -> [SettingsDocument] {
        Array(scopes.values)
    }

    func saveScope(_ scopeName: String, values: [String: String]) async throws {
        scopes[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func getValue(scopeName: String, key: String) async throws -> String? {
        scopes[scopeName]?.values[key]
    }

    func setValue(scopeName: String, key: String, value: String) async throws {
        var values = scopes[scopeName]?.values ?? [:]
        values[key] = value
        scopes[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func deleteValue(scopeName: String, key: String) async throws {
        var values = scopes[scopeName]?.values ?? [:]
        values.removeValue(forKey: key)
        scopes[scopeName] = SettingsDocument(scopeName: scopeName, values: values)
    }

    func observeScope(_ scopeName: String, listener: @escaping (SettingsDocument) -> Void) -> FirestoreListenerToken {
        listener(scopes[scopeName] ?? SettingsDocument(scopeName: scopeName, values: [:]))
        return FirestoreListenerToken {}
    }

    func observeAllScopes(_ listener: @escaping ([SettingsDocument]) -> Void) -> FirestoreListenerToken {
        listener(Array(scopes.values))
        return FirestoreListenerToken {}
    }
}
