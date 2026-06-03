import XCTest
@testable import AIAssistantHub

final class WaitForEventToolTests: XCTestCase {
    func testExecuteBlocksUntilGlobalEventUnlocks() async throws {
        let sharedLocks = SharedLockRegistry()
        let tool = WaitForEventTool(sharedLocks: sharedLocks)
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
            .string("event: something changed. Re-check active chats, issues, and pending client interactions.")
        )
    }
}

private actor WaitForEventFinishProbe {
    private(set) var finished = false

    func markFinished() {
        finished = true
    }
}
