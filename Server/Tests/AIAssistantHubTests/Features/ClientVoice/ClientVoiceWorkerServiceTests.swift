import XCTest
@testable import AIAssistantHub

@MainActor
final class ClientVoiceWorkerServiceTests: FirestoreIntegrationTestCase {
    func testInitializedRequestDoesNothingWhileClientIsAbsent() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let presenceRepository = ClientVoicePresenceStub(initialPresence: false)
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
        
        // Save an initialized request directly in the real repository
        _ = try await repository.createRequest(
            issueId: "issue-1",
            kind: .speak,
            status: .initialized,
            promptText: "hello"
        )

        try? await Task.sleep(nanoseconds: 200_000_000)

        // The request should still be initialized because client is absent
        let requests = try await repository.listRequests()
        XCTAssertEqual(requests.first?.status, .initialized)

        let isLocked = await sharedLocks.isLocked(id: "announce_to_client:speak-1")
        XCTAssertFalse(isLocked)

        await service.stop()
        await presenceService.stop()
    }

    func testSpeakRequestUnlocksOnlyAfterCompletionPersists() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let presenceRepository = ClientVoicePresenceStub(initialPresence: true)
        let presenceService = ClientVoicePresenceService(repository: presenceRepository)
        await presenceService.start()
        
        let service = ClientVoiceWorkerService(
            id: "client.voice.worker",
            title: "Voice Worker",
            repository: repository,
            sharedLocks: sharedLocks,
            presenceService: presenceService,
            speakPerformer: { _ in
                await CompletedSpeechSpeakHandler()
            }
        )

        let request = try await repository.createRequest(
            issueId: "issue-1",
            kind: .speak,
            status: .initialized,
            promptText: "hello"
        )
        let requestID = try XCTUnwrap(request.id)

        let waiterStarted = expectation(description: "waiter started")
        let waiterResumed = expectation(description: "waiter resumed")

        let waiter = Task {
            waiterStarted.fulfill()
            try await sharedLocks.lockAndWait(id: "announce_to_client:\(requestID)")
            waiterResumed.fulfill()
        }

        await fulfillment(of: [waiterStarted], timeout: 1.0)
        await service.start()

        // Wait for the worker to process the request, update it to completed, and unlock the lock
        await fulfillment(of: [waiterResumed], timeout: 3.0)
        _ = try await waiter.value

        let finalRequest = try await repository.getRequest(id: requestID)
        XCTAssertEqual(finalRequest.status, .completed)
        
        let isLocked = await sharedLocks.isLocked(id: "announce_to_client:\(requestID)")
        XCTAssertFalse(isLocked)
        XCTAssertEqual(service.state, .running)

        await service.stop()
        await presenceService.stop()
    }

    func testAskRequestOpensDialogOnlyWhenClientBecomesPresent() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let presenceRepository = ClientVoicePresenceStub(initialPresence: false)
        let presenceService = ClientVoicePresenceService(repository: presenceRepository)
        await presenceService.start()

        let askDialogOpened = expectation(description: "ask dialog opened")
        
        let request = try await repository.createRequest(
            issueId: "issue-1",
            kind: .ask,
            status: .initialized,
            promptText: "hello"
        )
        let requestID = try XCTUnwrap(request.id)

        let service = ClientVoiceWorkerService(
            id: "client.voice.worker",
            title: "Voice Worker",
            repository: repository,
            sharedLocks: sharedLocks,
            presenceService: presenceService,
            presentAskDialog: { req, _ in
                XCTAssertEqual(req.id, requestID)
                askDialogOpened.fulfill()
            },
            speakPerformer: { _ in
                await CompletedSpeechSpeakHandler()
            }
        )

        await service.start()

        // The request status should be initialized initially since client is absent
        let req1 = try await repository.getRequest(id: requestID)
        XCTAssertEqual(req1.status, .initialized)

        // Make client present
        try await presenceService.setPresent()

        await fulfillment(of: [askDialogOpened], timeout: 2.0)

        // Now request status should be waitingUser
        let req2 = try await repository.getRequest(id: requestID)
        XCTAssertEqual(req2.status, .waitingUser)

        await service.stop()
        await presenceService.stop()
    }

    func testStartAndStopUpdateRuntimeState() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let presenceRepository = ClientVoicePresenceStub(initialPresence: true)
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

        await service.stop()
        XCTAssertEqual(service.state, .stopped)
    }

    func testSpeakRequestUnlocksOnlyAfterSpeechCompletesUsingDeferredHandler() async throws {
        let repository = FirestoreClientInteractionRequestRepository(scope: scope)
        let sharedLocks = SharedLockRegistry()
        let presenceRepository = ClientVoicePresenceStub(initialPresence: true)
        let presenceService = ClientVoicePresenceService(repository: presenceRepository)
        await presenceService.start()

        let handler = WorkerDeferredSpeechSpeakHandler()

        let service = ClientVoiceWorkerService(
            id: "client.voice.worker",
            title: "Voice Worker",
            repository: repository,
            sharedLocks: sharedLocks,
            presenceService: presenceService,
            speakPerformer: { _ in
                handler
            }
        )

        let request = try await repository.createRequest(
            issueId: "issue-1",
            kind: .speak,
            status: .initialized,
            promptText: "hello"
        )
        let requestID = try XCTUnwrap(request.id)

        // Lock first so any future waiter will suspend until unlock is called
        try await sharedLocks.lockAndWait(id: "announce_to_client:\(requestID)")

        let waiterStarted = expectation(description: "waiter started")
        let waiterResumed = expectation(description: "waiter resumed")

        let waiter = Task {
            waiterStarted.fulfill()
            try await sharedLocks.lockAndWait(id: "announce_to_client:\(requestID)")
            waiterResumed.fulfill()
        }

        await fulfillment(of: [waiterStarted], timeout: 1.0)
        await service.start()

        // Wait briefly for the worker to notice the request and process it
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Request status should have transitioned to speaking
        let intermediateRequest = try await repository.getRequest(id: requestID)
        XCTAssertEqual(intermediateRequest.status, .speaking)

        // The waiter should not be resumed yet
        let isLockedBefore = await sharedLocks.isLocked(id: "announce_to_client:\(requestID)")
        XCTAssertTrue(isLockedBefore)

        // Finish speaking
        handler.finish()

        // Wait for the lock to be unlocked and waiter to resume
        await fulfillment(of: [waiterResumed], timeout: 3.0)
        _ = try await waiter.value

        let finalRequest = try await repository.getRequest(id: requestID)
        XCTAssertEqual(finalRequest.status, .completed)

        let isLockedAfter = await sharedLocks.isLocked(id: "announce_to_client:\(requestID)")
        XCTAssertFalse(isLockedAfter)

        await service.stop()
        await presenceService.stop()
    }
}

private final class ClientVoicePresenceStub: ClientVoicePresenceRepository {
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

private final class WorkerDeferredSpeechSpeakHandler: SpeechSpeakHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    override func await() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if finished {
                lock.unlock()
                continuation.resume()
                return
            }

            continuations.append(continuation)
            lock.unlock()
        }
    }

    override func cancel() {
        finish()
    }

    func finish() {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }

        finished = true
        let continuations = self.continuations
        self.continuations.removeAll()
        lock.unlock()

        continuations.forEach { $0.resume() }
    }
}
