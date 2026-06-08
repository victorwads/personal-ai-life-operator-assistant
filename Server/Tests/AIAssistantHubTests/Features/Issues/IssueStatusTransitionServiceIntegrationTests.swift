import Foundation
import XCTest
@testable import AIAssistantHub

final class IssueStatusTransitionServiceIntegrationTests: FirestoreIntegrationTestCase {
    func testResolveIssueRejectsEmptyReasonAtRepositoryLevel() async throws {
        let repository = FirestoreIssueRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        do {
            try await repository.resolveIssue(issueId: "issue-1", reason: "   ")
            XCTFail("Expected empty reason validation to throw.")
        } catch let error as IssueRepositoryError {
            guard case .invalidReason = error else {
                return XCTFail("Expected invalidReason, got \(error)")
            }
        }
    }

    func testResolveIssueAppendsTimelineAndMarksIssueFinished() async throws {
        let service = await makeService()
        let repository = FirestoreIssueRepository(scope: scope)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        try await service.resolveIssue(issueId: "issue-1", reason: "Resolved manually")

        let issue = try await repository.getById("issue-1")
        XCTAssertEqual(issue?.status, .resolved)
        XCTAssertEqual(issue?.finished, true)
        XCTAssertNil(issue?.suspendUntil)

        let timelineItems = try await timelineRepository.listItems(for: "issue-1")
        XCTAssertEqual(timelineItems.count, 1)
        XCTAssertEqual(timelineItems.first?.kind, "issueResolved")
        XCTAssertEqual(timelineItems.first?.reason, "Resolved manually")
        XCTAssertEqual(timelineItems.first?.previousStatus, .pending)
        XCTAssertNotNil(timelineItems.first?.changedAt)
    }

    func testCancelIssueAppendsTimelineAndMarksIssueFinished() async throws {
        let service = await makeService()
        let repository = FirestoreIssueRepository(scope: scope)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        try await service.cancelIssue(issueId: "issue-2", reason: "Not needed anymore")

        let issue = try await repository.getById("issue-2")
        XCTAssertEqual(issue?.status, .cancelled)
        XCTAssertEqual(issue?.finished, true)
        XCTAssertNil(issue?.suspendUntil)

        let timelineItems = try await timelineRepository.listItems(for: "issue-2")
        XCTAssertEqual(timelineItems.count, 1)
        XCTAssertEqual(timelineItems.first?.kind, "issueCancelled")
        XCTAssertEqual(timelineItems.first?.reason, "Not needed anymore")
        XCTAssertEqual(timelineItems.first?.previousStatus, .pending)
    }

    func testSuspendAndReactivatePreservesAuditHistory() async throws {
        let service = await makeService()
        let repository = FirestoreIssueRepository(scope: scope)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        let suspendUntil = Date(timeIntervalSinceNow: 3600)
        try await service.suspendIssue(
            issueId: "issue-1",
            suspendUntil: suspendUntil,
            reason: "Waiting on the client"
        )
        try await service.reactivateIssue(issueId: "issue-1", reason: "Client replied")

        let issue = try await repository.getById("issue-1")
        XCTAssertEqual(issue?.status, .pending)
        XCTAssertEqual(issue?.finished, false)
        XCTAssertNil(issue?.suspendUntil)

        let timelineItems = try await timelineRepository.listItems(for: "issue-1")
        XCTAssertEqual(timelineItems.count, 2)
        XCTAssertEqual(timelineItems[0].kind, "issueSuspended")
        XCTAssertEqual(timelineItems[0].reason, "Waiting on the client")
        XCTAssertNotNil(timelineItems[0].suspendUntil)
        if let savedSuspendUntil = timelineItems[0].suspendUntil {
            XCTAssertEqual(savedSuspendUntil.timeIntervalSince1970, suspendUntil.timeIntervalSince1970, accuracy: 0.001)
        }
        XCTAssertEqual(timelineItems[1].kind, "issueReactivated")
        XCTAssertEqual(timelineItems[1].reason, "Client replied")
        XCTAssertEqual(timelineItems[1].previousStatus, .suspended)
    }

    func testReactivateCancelledIssueReopensIt() async throws {
        let service = await makeService()
        let repository = FirestoreIssueRepository(scope: scope)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope)

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        try await service.cancelIssue(issueId: "issue-2", reason: "Cancelled by mistake")
        try await service.reactivateIssue(issueId: "issue-2", reason: "This issue still needs work")

        let issue = try await repository.getById("issue-2")
        XCTAssertEqual(issue?.status, .pending)
        XCTAssertEqual(issue?.finished, false)
        XCTAssertNil(issue?.suspendUntil)

        let timelineItems = try await timelineRepository.listItems(for: "issue-2")
        XCTAssertEqual(timelineItems.count, 2)
        XCTAssertEqual(timelineItems[0].kind, "issueCancelled")
        XCTAssertEqual(timelineItems[1].kind, "issueReactivated")
        XCTAssertEqual(timelineItems[1].previousStatus, .cancelled)
    }

    func testSuspendIssueRejectsPastDate() async throws {
        let service = await makeService()

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        do {
            try await service.suspendIssue(
                issueId: "issue-1",
                suspendUntil: Date(timeIntervalSinceNow: -60),
                reason: "This should fail"
            )
            XCTFail("Expected suspendUntil validation to throw.")
        } catch let error as IssueStatusTransitionError {
            guard case .suspendUntilMustBeFuture = error else {
                return XCTFail("Expected suspendUntilMustBeFuture, got \(error)")
            }
        }
    }

    func testReactivateActiveIssueIsRejected() async throws {
        let service = await makeService()

        try await fixtureBuilder.importFixture(named: "issue-basic.json")

        do {
            try await service.reactivateIssue(issueId: "issue-1", reason: "Already active")
            XCTFail("Expected active reactivation to throw.")
        } catch let error as IssueStatusTransitionError {
            guard case .invalidTransition(let action, let currentStatus) = error else {
                return XCTFail("Expected invalidTransition, got \(error)")
            }
            XCTAssertEqual(action, "Reactivate")
            XCTAssertEqual(currentStatus, .pending)
        }
    }

    @MainActor
    private func makeService() -> IssueStatusTransitionService {
        let dateProvider = IncrementingDateProvider(
            start: Date(timeIntervalSince1970: 1_728_000_000)
        )
        let repository = FirestoreIssueRepository(scope: scope, dateProvider: dateProvider.next)
        let timelineRepository = FirestoreIssueTimelineRepository(scope: scope, dateProvider: dateProvider.next)
        return IssueStatusTransitionService(
            repository: repository,
            timelineRepository: timelineRepository,
            dateProvider: dateProvider.next
        )
    }
}

private final class IncrementingDateProvider {
    private var current: Date

    init(start: Date) {
        self.current = start
    }

    func next() -> Date {
        defer {
            current = current.addingTimeInterval(1)
        }
        return current
    }
}
