import XCTest
@testable import AIAssistantHub

final class WaitForEventToolTests: XCTestCase {
    func testExecuteReturnsImmediatelyWhenPendingWorkAlreadyExists() async throws {
        let sharedLocks = SharedLockRegistry()
        let tool = WaitForEventTool(
            sharedLocks: sharedLocks,
            pendingWorkProviders: [
                PendingWorkProviderStub(
                    section: PendingWorkSection(
                        title: "Unhandled chats",
                        lines: ["Family (chatId: wa:123)"]
                    )
                )
            ]
        )

        let result = try await tool.execute(
            MCPToolCall(name: "wait_for_event", arguments: [:]),
            context: MCPServerContext()
        )

        XCTAssertEqual(
            result,
            .string(
                """
                event: pending work already exists.

                Pending work:
                Unhandled chats:
                - Family (chatId: wa:123)

                Start a new cycle and inspect active chats, issues, and client interactions.
                """
            )
        )
    }

    func testExecuteBlocksUntilGlobalEventUnlocks() async throws {
        let sharedLocks = SharedLockRegistry()
        let tool = WaitForEventTool(
            sharedLocks: sharedLocks,
            pendingWorkProviders: [PendingWorkProviderStub(section: nil)]
        )
        let finishProbe = WaitForEventFinishProbe()

        let task = Task<MCPJSONValue, Error> {
            do {
                let result = try await tool.execute(
                    MCPToolCall(name: "wait_for_event", arguments: [:]),
                    context: MCPServerContext()
                )
                await finishProbe.markFinished()
                return result
            } catch {
                await finishProbe.markFinished()
                throw error
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        let finishedBeforeUnlock = await finishProbe.finished
        XCTAssertFalse(finishedBeforeUnlock)

        await sharedLocks.unlock(id: SharedLockIDs.globalEvent)
        let result = try await task.value

        XCTAssertEqual(
            result,
            .string("event: global_event unlocked. Something changed and released the global wait lock. Start a new cycle and inspect active chats, issues, and client interactions.")
        )
    }

    func testExecuteReturnsPendingWorkAfterGlobalEventUnlockWhenWorkExists() async throws {
        let sharedLocks = SharedLockRegistry()
        let provider = PendingWorkProviderStateStub()
        let tool = WaitForEventTool(
            sharedLocks: sharedLocks,
            pendingWorkProviders: [provider]
        )
        let finishProbe = WaitForEventFinishProbe()

        let task = Task<MCPJSONValue, Error> {
            do {
                let result = try await tool.execute(
                    MCPToolCall(name: "wait_for_event", arguments: [:]),
                    context: MCPServerContext()
                )
                await finishProbe.markFinished()
                return result
            } catch {
                await finishProbe.markFinished()
                throw error
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        let finishedBeforeUnlock = await finishProbe.finished
        XCTAssertFalse(finishedBeforeUnlock)

        await provider.setSection(
            PendingWorkSection(
                title: "Client interaction requests waiting for agent",
                lines: [
                    "issueId: issue-1 | issueTitle: Trip | prompt: Can I go tomorrow? | response: Yes."
                ]
            )
        )
        await sharedLocks.unlock(id: SharedLockIDs.globalEvent)
        let result = try await task.value

        XCTAssertEqual(
            result,
            .string(
                """
                event: global_event unlocked and pending work is now available.

                Pending work:
                Client interaction requests waiting for agent:
                - issueId: issue-1 | issueTitle: Trip | prompt: Can I go tomorrow? | response: Yes.

                Start a new cycle and inspect active chats, issues, and client interactions.
                """
            )
        )
    }
}

private actor WaitForEventFinishProbe {
    private(set) var finished = false

    func markFinished() {
        finished = true
    }
}

private struct PendingWorkProviderStub: PendingWorkProvider {
    let section: PendingWorkSection?

    func pendingWorkSection() async throws -> PendingWorkSection? {
        section
    }
}

private actor PendingWorkProviderStateStub: PendingWorkProvider {
    private var section: PendingWorkSection? = nil

    func setSection(_ section: PendingWorkSection?) {
        self.section = section
    }

    func pendingWorkSection() async throws -> PendingWorkSection? {
        section
    }
}
