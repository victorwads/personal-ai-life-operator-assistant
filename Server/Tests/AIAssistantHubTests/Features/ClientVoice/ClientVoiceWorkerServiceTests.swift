import XCTest
@testable import AIAssistantHub

@MainActor
final class ClientVoiceWorkerServiceTests: XCTestCase {
    func testInitializedRequestDoesNothingWhileClientIsAbsent() async {
        let repository = ClientVoiceWorkerRepositorySpy()
        let sharedLocks = SharedLockRegistry()
        let presenceRepository = ClientVoicePresenceRepositorySpy(initialPresence: false)
        let presenceService = ClientVoicePresenceService(repository: presenceRepository)
        await presenceService.start()
        let service = ClientVoiceWorkerService(
            id: "client.voice.worker",
            title: "Voice Worker",
            repository: repository,
            sharedLocks: sharedLocks,
            presenceService: presenceService
        )

        await service.start()
        repository.emit([
            ClientInteractionRequest(
                id: "speak-1",
                issueId: "issue-1",
                kind: .speak,
                status: .initialized,
                promptText: "hello"
            )
        ])

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(repository.recordedCalls.isEmpty)
        let isLocked = await sharedLocks.isLocked(id: "speak_to_client:speak-1")
        XCTAssertFalse(isLocked)

        await service.stop()
        await presenceService.stop()
    }

    func testSpeakRequestUnlocksOnlyAfterCompletionPersists() async throws {
        let repository = ClientVoiceWorkerRepositorySpy()
        let sharedLocks = SharedLockRegistry()
        let presenceRepository = ClientVoicePresenceRepositorySpy(initialPresence: true)
        let presenceService = ClientVoicePresenceService(repository: presenceRepository)
        await presenceService.start()
        let service = ClientVoiceWorkerService(
            id: "client.voice.worker",
            title: "Voice Worker",
            repository: repository,
            sharedLocks: sharedLocks,
            presenceService: presenceService,
            speakPerformer: { _ in
                CompletedSpeechSpeakHandler()
            }
        )

        let waiterStarted = expectation(description: "waiter started")
        let waiterResumed = expectation(description: "waiter resumed")
        let completionPersisted = expectation(description: "completion persisted")

        repository.onMarkCompleted = {
            completionPersisted.fulfill()
        }

        let waiter = Task {
            waiterStarted.fulfill()
            try await sharedLocks.lockAndWait(id: "speak_to_client:speak-1")
            waiterResumed.fulfill()
        }

        await fulfillment(of: [waiterStarted], timeout: 1.0)
        await service.start()

        repository.emit([
            ClientInteractionRequest(
                id: "speak-1",
                issueId: "issue-1",
                kind: .speak,
                status: .initialized,
                promptText: "hello"
            )
        ])

        await fulfillment(of: [completionPersisted, waiterResumed], timeout: 3.0, enforceOrder: true)
        _ = try await waiter.value

        XCTAssertEqual(repository.recordedCalls, [
            .markSpeaking("speak-1"),
            .markCompleted("speak-1")
        ])
        let isLocked = await sharedLocks.isLocked(id: "speak_to_client:speak-1")
        XCTAssertFalse(isLocked)
        XCTAssertEqual(service.state, .running)

        await service.stop()
        await presenceService.stop()
    }

    func testAskRequestOpensDialogOnlyWhenClientBecomesPresent() async throws {
        let repository = ClientVoiceWorkerRepositorySpy()
        let sharedLocks = SharedLockRegistry()
        let presenceRepository = ClientVoicePresenceRepositorySpy(initialPresence: false)
        let presenceService = ClientVoicePresenceService(repository: presenceRepository)
        await presenceService.start()

        let askDialogOpened = expectation(description: "ask dialog opened")
        let service = ClientVoiceWorkerService(
            id: "client.voice.worker",
            title: "Voice Worker",
            repository: repository,
            sharedLocks: sharedLocks,
            presenceService: presenceService,
            presentAskDialog: { request, _ in
                XCTAssertEqual(request.id, "ask-1")
                askDialogOpened.fulfill()
            },
            speakPerformer: { _ in
                CompletedSpeechSpeakHandler()
            }
        )

        await service.start()
        repository.emit([
            ClientInteractionRequest(
                id: "ask-1",
                issueId: "issue-1",
                kind: .ask,
                status: .initialized,
                promptText: "hello"
            )
        ])

        try await presenceService.setPresent()

        await fulfillment(of: [askDialogOpened], timeout: 2.0)
        XCTAssertEqual(repository.recordedCalls, [
            .markSpeaking("ask-1"),
            .markWaitingUser("ask-1")
        ])

        await service.stop()
        await presenceService.stop()
    }

    func testStartAndStopUpdateRuntimeState() async {
        let repository = ClientVoiceWorkerRepositorySpy()
        let presenceRepository = ClientVoicePresenceRepositorySpy(initialPresence: true)
        let presenceService = ClientVoicePresenceService(repository: presenceRepository)
        let service = ClientVoiceWorkerService(
            id: "client.voice.worker",
            title: "Voice Worker",
            repository: repository,
            sharedLocks: SharedLockRegistry(),
            presenceService: presenceService
        )

        XCTAssertEqual(service.state, .stopped)

        await service.start()
        XCTAssertEqual(service.state, .running)
        XCTAssertEqual(repository.observeRequestsCallCount, 1)

        await service.stop()
        XCTAssertEqual(service.state, .stopped)
        XCTAssertTrue(repository.listenerCancelCalled)
    }
}

private final class ClientVoiceWorkerRepositorySpy: ClientInteractionRequestRepository, @unchecked Sendable {
    enum Call: Equatable {
        case markSpeaking(String)
        case markWaitingUser(String)
        case markCompleted(String)
    }

    private let lock = NSLock()
    private(set) var recordedCalls: [Call] = []
    private(set) var observeRequestsCallCount = 0
    private(set) var listenerCancelCalled = false
    var onMarkCompleted: (() -> Void)?
    private var listener: (([ClientInteractionRequest]) -> Void)?

    func emit(_ requests: [ClientInteractionRequest]) {
        listener?(requests)
    }

    func listRequests() async throws -> [ClientInteractionRequest] { [] }

    func observeRequests(_ listener: @escaping ([ClientInteractionRequest]) -> Void) -> FirestoreListenerToken {
        observeRequestsCallCount += 1
        self.listener = listener
        return FirestoreListenerToken { [weak self] in
            self?.listenerCancelCalled = true
        }
    }

    func getRequest(id _: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    func createRequest(
        issueId _: String,
        kind _: ClientInteractionRequest.Kind,
        status _: ClientInteractionRequest.Status,
        promptText _: String
    ) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    func markWaitingAgent(id _: String, responseText _: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    func markSpeaking(id: String) async throws -> ClientInteractionRequest {
        append(.markSpeaking(id))
        return ClientInteractionRequest(
            id: id,
            issueId: "issue-1",
            kind: .speak,
            status: .speaking,
            promptText: "hello"
        )
    }

    func markWaitingUser(id: String) async throws -> ClientInteractionRequest {
        append(.markWaitingUser(id))
        return ClientInteractionRequest(
            id: id,
            issueId: "issue-1",
            kind: .ask,
            status: .waitingUser,
            promptText: "hello"
        )
    }

    func markCompleted(id: String) async throws -> ClientInteractionRequest {
        append(.markCompleted(id))
        onMarkCompleted?()
        return ClientInteractionRequest(
            id: id,
            issueId: "issue-1",
            kind: .speak,
            status: .completed,
            promptText: "hello"
        )
    }

    func markCancelled(id _: String) async throws -> ClientInteractionRequest {
        throw ClientInteractionRequestRepositoryError.requestNotFound("unused")
    }

    private func append(_ call: Call) {
        lock.lock()
        recordedCalls.append(call)
        lock.unlock()
    }
}

private final class ClientVoicePresenceRepositorySpy: ClientVoicePresenceRepository {
    private var onChange: ((Bool) -> Void)?
    private(set) var isPresent: Bool

    init(initialPresence: Bool) {
        isPresent = initialPresence
    }

    func observePresence(_ onChange: @escaping (Bool) -> Void) -> RealtimeDatabaseListenerToken {
        self.onChange = onChange
        onChange(isPresent)
        return RealtimeDatabaseListenerToken {}
    }

    func setPresence(_ isPresent: Bool) async throws {
        self.isPresent = isPresent
        onChange?(isPresent)
    }

    func getPresence() async throws -> Bool {
        isPresent
    }
}
