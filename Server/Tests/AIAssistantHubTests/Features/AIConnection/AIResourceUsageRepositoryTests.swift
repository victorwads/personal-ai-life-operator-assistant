import XCTest
import FirebaseFirestore
@testable import AIAssistantHub

final class AIResourceUsageRepositoryTests: XCTestCase {
    func testAssistantUsageUpdatesTotalAndAssistantPools() async {
        let repository = NoopAIResourceUsageRepository()
        await repository.add(
            AIResourceUsageAddition(
                pool: .assistant,
                provider: .openRouter,
                model: "model-1",
                usage: AIUsage(
                    promptTokens: 100,
                    completionTokens: 50,
                    reasoningTokens: 25,
                    totalTokens: 175,
                    cachedInputTokens: 10
                ),
                success: true
            )
        )

        XCTAssertEqual(repository.currentUse.total.requests, 1)
        XCTAssertEqual(repository.currentUse.total.inputTokens, 100)
        XCTAssertEqual(repository.currentUse.total.outputTokens, 50)
        XCTAssertEqual(repository.currentUse.total.reasoningTokens, 25)
        XCTAssertEqual(repository.currentUse.total.cachedInputTokens, 10)
        XCTAssertEqual(repository.currentUse.total.totalTokens, 175)

        XCTAssertEqual(repository.currentUse.assistant.requests, 1)
        XCTAssertEqual(repository.currentUse.assistant.inputTokens, 100)
        XCTAssertEqual(repository.currentUse.assistant.outputTokens, 50)
        XCTAssertEqual(repository.currentUse.assistant.reasoningTokens, 25)
        XCTAssertEqual(repository.currentUse.assistant.cachedInputTokens, 10)
        XCTAssertEqual(repository.currentUse.assistant.totalTokens, 175)

        XCTAssertEqual(repository.currentUse.imageExtraction.requests, 0)
    }

    func testImageExtractionUsageUpdatesTotalAndImageExtractionPools() async {
        let repository = NoopAIResourceUsageRepository()
        await repository.add(
            AIResourceUsageAddition(
                pool: .imageExtraction,
                provider: .openRouter,
                model: "image-model",
                usage: AIUsage(
                    promptTokens: 20,
                    completionTokens: 30,
                    reasoningTokens: nil,
                    totalTokens: nil,
                    cachedInputTokens: nil
                ),
                success: true
            )
        )

        XCTAssertEqual(repository.currentUse.total.requests, 1)
        XCTAssertEqual(repository.currentUse.total.inputTokens, 20)
        XCTAssertEqual(repository.currentUse.total.outputTokens, 30)
        XCTAssertEqual(repository.currentUse.total.reasoningTokens, 0)
        XCTAssertEqual(repository.currentUse.total.cachedInputTokens, 0)
        XCTAssertEqual(repository.currentUse.total.totalTokens, 50)

        XCTAssertEqual(repository.currentUse.assistant.requests, 0)
        XCTAssertEqual(repository.currentUse.imageExtraction.requests, 1)
        XCTAssertEqual(repository.currentUse.imageExtraction.inputTokens, 20)
        XCTAssertEqual(repository.currentUse.imageExtraction.outputTokens, 30)
        XCTAssertEqual(repository.currentUse.imageExtraction.totalTokens, 50)
    }

    func testNoopRepositoryLoadCurrentUseAndPendingUnsyncedUse() async throws {
        let repository = NoopAIResourceUsageRepository()
        let doc = try await repository.loadCurrentUse()
        XCTAssertEqual(doc.total.requests, 0)
        XCTAssertNil(repository.pendingUnsyncedUse)
    }
}

final class FirestoreAIResourceUsageRepositoryTests: FirestoreIntegrationTestCase {
    func testLoadCurrentUseReturnsEmptyWhenNoDocExists() async throws {
        let repo = FirestoreAIResourceUsageRepository(profileId: scope.profileId)
        let doc = try await repo.loadCurrentUse()
        
        XCTAssertEqual(doc.id, "usage")
        XCTAssertEqual(doc.total.requests, 0)
        XCTAssertEqual(doc.assistant.requests, 0)
        XCTAssertEqual(doc.imageExtraction.requests, 0)
        
        XCTAssertEqual(repo.currentUse.total.requests, 0)
    }

    func testLoadCurrentUseLoadsExistingDocAndUpdatesCaches() async throws {
        let repo = FirestoreAIResourceUsageRepository(profileId: scope.profileId)
        
        await repo.add(
            AIResourceUsageAddition(
                pool: .assistant,
                provider: .openRouter,
                model: "model-1",
                usage: AIUsage(
                    promptTokens: 10,
                    completionTokens: 20,
                    reasoningTokens: 0,
                    totalTokens: 30,
                    cachedInputTokens: 0
                ),
                success: true
            )
        )
        
        await repo.flush()
        
        let newRepo = FirestoreAIResourceUsageRepository(profileId: scope.profileId)
        XCTAssertEqual(newRepo.currentUse.total.requests, 0)
        
        let loadedDoc = try await newRepo.loadCurrentUse()
        XCTAssertEqual(loadedDoc.total.requests, 1)
        XCTAssertEqual(loadedDoc.total.totalTokens, 30)
        XCTAssertEqual(newRepo.currentUse.total.requests, 1)
    }

    func testPendingUnsyncedUseExposesToSendCache() async throws {
        let repo = FirestoreAIResourceUsageRepository(profileId: scope.profileId)
        XCTAssertEqual(repo.pendingUnsyncedUse?.total.requests ?? 0, 0)
        
        await repo.add(
            AIResourceUsageAddition(
                pool: .assistant,
                provider: .openRouter,
                model: "model-1",
                usage: AIUsage(
                    promptTokens: 10,
                    completionTokens: 20,
                    reasoningTokens: 0,
                    totalTokens: 30,
                    cachedInputTokens: 0
                ),
                success: true
            )
        )
        
        XCTAssertEqual(repo.pendingUnsyncedUse?.total.requests, 1)
        
        await repo.flush()
        XCTAssertEqual(repo.pendingUnsyncedUse?.total.requests ?? 0, 0)
    }
}
