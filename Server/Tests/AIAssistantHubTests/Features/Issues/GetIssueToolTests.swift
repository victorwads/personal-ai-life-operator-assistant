import XCTest
@testable import AIAssistantHub

final class GetIssueToolTests: FirestoreIntegrationTestCase {
    func testExecuteReturnsStructuredPlainTextWithTimelineChatsSentMessagesAndClientVoice() async throws {
        try await fixtureBuilder.importFixture(named: "issue-mcp-related-data.json")

        let issueRepository = FirestoreIssueRepository(scope: scope)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope)
        let sentMessageRepository = FirestoreSentMessageRepository(scope: scope)
        let clientInteractionRepository = FirestoreClientInteractionRequestRepository(scope: scope)
        let chatRepository = FirestoreChatRepository(scope: scope)

        let tool = GetIssueTool(
            repository: issueRepository,
            timelineRepository: timelineRepository,
            sentMessagesProvider: { issueId in
                try await sentMessageRepository.listByIssueId(issueId)
            },
            clientInteractionRequestsProvider: { issueId in
                try await clientInteractionRepository.listRequests(issueId: issueId)
            },
            chatProvider: { chatId in
                try await chatRepository.getChat(id: chatId)
            }
        )

        let result = try await tool.execute(
            MCPToolCall(name: "get_issue", arguments: ["id": .string("issue-xml-1")]),
            context: MCPServerContext()
        )

        XCTAssertEqual(
            result,
            .string(
                """
                <issue id="issue-xml-1">
                <title>Escalate billing mismatch</title>
                <description>Client says the invoice total does not match the signed proposal and wants a corrected amount before paying. Additional context exists here only to force the active issue list to truncate the description cleanly.</description>
                <initialRequest>The client asked us to review the latest invoice and explain the mismatch.</initialRequest>
                <resolutionCondition>The invoice is corrected and the client confirms the new total is right.</resolutionCondition>
                <priority number="5">altissima</priority>
                <status>pending</status>
                <timeline>
                <item>Opened after the client reported a mismatch in the billed amount.</item>
                <item>Confirmed the proposal total and started invoice comparison.</item>
                </timeline>
                <relatedChats>
                <chat id="chat-linked-1">
                <title>Budget Chat</title>
                </chat>
                <chat id="chat-linked-2">
                <title>Voice Follow-up</title>
                </chat>
                </relatedChats>
                <sentMessages>
                <sentMessage chatId="chat-linked-1" status="failed">
                <chatTitle>Budget Chat</chatTitle>
                <content>Tried to send the payment link again.</content>
                <errorMessage>WhatsApp Web was offline.</errorMessage>
                </sentMessage>
                <sentMessage chatId="chat-linked-1" status="sent" sentAt="2026-06-08T10:05:00Z">
                <chatTitle>Budget Chat</chatTitle>
                <content>Sent the corrected invoice summary.</content>
                <content>Asked the client to confirm the new total.</content>
                </sentMessage>
                </sentMessages>
                <clientInteractions>
                <clientVoice kind="speak" status="completed">
                <prompt>The invoice was corrected.</prompt>
                </clientVoice>
                <clientVoice kind="ask" status="waitingAgent" device="desktop">
                <prompt>Can you call me after lunch?</prompt>
                <response>I can call you at 14:00.</response>
                </clientVoice>
                </clientInteractions>
                </issue>
                """
            )
        )
    }

    func testExecuteOmitsEmptySectionsAndNullFields() async throws {
        try await fixtureBuilder.importFixture(named: "issue-mcp-related-data.json")

        let issueRepository = FirestoreIssueRepository(scope: scope)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope)
        let sentMessageRepository = FirestoreSentMessageRepository(scope: scope)
        let clientInteractionRepository = FirestoreClientInteractionRequestRepository(scope: scope)
        let chatRepository = FirestoreChatRepository(scope: scope)

        let tool = GetIssueTool(
            repository: issueRepository,
            timelineRepository: timelineRepository,
            sentMessagesProvider: { issueId in
                try await sentMessageRepository.listByIssueId(issueId)
            },
            clientInteractionRequestsProvider: { issueId in
                try await clientInteractionRepository.listRequests(issueId: issueId)
            },
            chatProvider: { chatId in
                try await chatRepository.getChat(id: chatId)
            }
        )

        let result = try await tool.execute(
            MCPToolCall(name: "get_issue", arguments: ["id": .string("issue-xml-2")]),
            context: MCPServerContext()
        )

        XCTAssertEqual(
            result,
            .string(
                """
                <issue id="issue-xml-2">
                <title>Prepare renewal summary</title>
                <description>Summarize the renewal terms before the Friday meeting.</description>
                <initialRequest>Prepare a short briefing for the renewal call.</initialRequest>
                <resolutionCondition>The summary is ready and shared before the meeting.</resolutionCondition>
                <priority number="2">baixa</priority>
                <status>pending</status>
                </issue>
                """
            )
        )
    }
}
