import XCTest
@testable import AIAssistantHub

final class SharedLockRegistryTests: XCTestCase {
    func testEventsEmitLockedAndUnlockedForLockLifecycle() async throws {
        let registry = SharedLockRegistry()
        let stream = await registry.events()
        let collectedEvents = Task { () -> [SharedLockEvent] in
            var events: [SharedLockEvent] = []

            for await event in stream {
                events.append(event)

                if events.count == 2 {
                    break
                }
            }

            return events
        }

        let waiterOneStarted = expectation(description: "waiter one started")
        let waiterTwoStarted = expectation(description: "waiter two started")

        let waiterOne = Task {
            waiterOneStarted.fulfill()
            try await registry.lockAndWait(id: "event")
        }

        let waiterTwo = Task {
            waiterTwoStarted.fulfill()
            try await registry.lockAndWait(id: "event")
        }

        await fulfillment(of: [waiterOneStarted, waiterTwoStarted], timeout: 1.0)
        await registry.unlock(id: "event")

        _ = try await waiterOne.value
        _ = try await waiterTwo.value

        let events = await collectedEvents.value
        XCTAssertEqual(events, [
            SharedLockEvent(kind: .locked, id: "event"),
            SharedLockEvent(kind: .unlocked, id: "event")
        ])
    }

    func testTwoWaitersResumeOnSingleUnlock() async throws {
        let registry = SharedLockRegistry()
        let waiterOneStarted = expectation(description: "waiter one started")
        let waiterTwoStarted = expectation(description: "waiter two started")
        let waiterOneResumed = expectation(description: "waiter one resumed")
        let waiterTwoResumed = expectation(description: "waiter two resumed")

        let waiterOne = Task {
            waiterOneStarted.fulfill()
            try await registry.lockAndWait(id: "event")
            waiterOneResumed.fulfill()
        }

        let waiterTwo = Task {
            waiterTwoStarted.fulfill()
            try await registry.lockAndWait(id: "event")
            waiterTwoResumed.fulfill()
        }

        await fulfillment(of: [waiterOneStarted, waiterTwoStarted], timeout: 1.0)
        let isLockedBeforeUnlock = await registry.isLocked(id: "event")
        XCTAssertTrue(isLockedBeforeUnlock)

        await registry.unlock(id: "event")

        await fulfillment(of: [waiterOneResumed, waiterTwoResumed], timeout: 1.0)
        _ = try await waiterOne.value
        _ = try await waiterTwo.value
        let isLockedAfterUnlock = await registry.isLocked(id: "event")
        XCTAssertFalse(isLockedAfterUnlock)
    }

    func testUnlockWithoutActiveLockIsNoOp() async {
        let registry = SharedLockRegistry()

        await registry.unlock(id: "missing")

        let isMissingLocked = await registry.isLocked(id: "missing")
        let activeLocks = await registry.activeLockIDs()
        XCTAssertFalse(isMissingLocked)
        XCTAssertEqual(activeLocks, [])
    }

    func testCancellingOneWaiterDoesNotUnlockOthers() async throws {
        let registry = SharedLockRegistry()
        let survivorStarted = expectation(description: "survivor started")
        let cancelledStarted = expectation(description: "cancelled waiter started")
        let survivorResumed = expectation(description: "survivor resumed")

        let survivor = Task {
            survivorStarted.fulfill()
            try await registry.lockAndWait(id: "event")
            survivorResumed.fulfill()
        }

        let cancelledWaiter = Task {
            cancelledStarted.fulfill()
            try await registry.lockAndWait(id: "event")
        }

        await fulfillment(of: [survivorStarted, cancelledStarted], timeout: 1.0)
        let activeLocksBeforeCancel = await registry.activeLockIDs()
        XCTAssertEqual(activeLocksBeforeCancel, ["event"])

        cancelledWaiter.cancel()

        do {
            _ = try await cancelledWaiter.value
            XCTFail("Expected cancelled waiter to throw CancellationError.")
        } catch is CancellationError {}

        let stillLockedAfterCancel = await registry.isLocked(id: "event")
        XCTAssertTrue(stillLockedAfterCancel)

        await registry.unlock(id: "event")

        await fulfillment(of: [survivorResumed], timeout: 1.0)
        _ = try await survivor.value
        let isLockedAfterFinalUnlock = await registry.isLocked(id: "event")
        XCTAssertFalse(isLockedAfterFinalUnlock)
    }
}
