import XCTest
@testable import AIAssistantHub

@MainActor
final class SpeechSpeakHandlerTests: XCTestCase {
    func testAwaitDoesNotResumeBeforeFinish() async throws {
        let handler = DeferredSpeechSpeakHandler()
        let expectation = XCTestExpectation(description: "await finished")
        expectation.isInverted = true
        
        let task = Task {
            await handler.await()
            expectation.fulfill()
        }
        
        await XCTWaiter().fulfillment(of: [expectation], timeout: 0.2)
        
        handler.finish()
        await task.value
    }
    
    func testAwaitResumesAfterFinish() async throws {
        let handler = DeferredSpeechSpeakHandler()
        let expectation = XCTestExpectation(description: "await finished")
        
        let task = Task {
            await handler.await()
            expectation.fulfill()
        }
        
        handler.finish()
        
        await XCTWaiter().fulfillment(of: [expectation], timeout: 1.0)
        await task.value
    }
    
    func testCancelResumesAwait() async throws {
        let handler = DeferredSpeechSpeakHandler()
        let expectation = XCTestExpectation(description: "await finished after cancel")
        
        let task = Task {
            await handler.await()
            expectation.fulfill()
        }
        
        handler.cancel()
        
        await XCTWaiter().fulfillment(of: [expectation], timeout: 1.0)
        await task.value
    }
}

private final class DeferredSpeechSpeakHandler: SpeechSpeakHandler, @unchecked Sendable {
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
