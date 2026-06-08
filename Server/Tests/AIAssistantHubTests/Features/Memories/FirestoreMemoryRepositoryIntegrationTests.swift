import XCTest
@testable import AIAssistantHub

final class FirestoreMemoryRepositoryIntegrationTests: FirestoreIntegrationTestCase {
    func testSaveByKeyCreatesMemoryWhenKeyDoesNotExist() async throws {
        let repository = FirestoreMemoryRepository(scope: scope)

        let savedMemory = try await repository.saveByKey(
            key: "client_language",
            value: "Portuguese"
        )

        XCTAssertNotNil(savedMemory.id)
        XCTAssertEqual(savedMemory.key, "client_language")
        XCTAssertEqual(savedMemory.value, "Portuguese")

        let persistedMemories = try await repository.query(
            matching: ["key": "client_language"]
        )
        XCTAssertEqual(persistedMemories.count, 1)
        XCTAssertEqual(persistedMemories.first?.value, "Portuguese")
    }

    func testSaveByKeyUpdatesExistingMemoryInsteadOfCreatingDuplicate() async throws {
        let repository = FirestoreMemoryRepository(scope: scope)

        let firstSave = try await repository.saveByKey(
            key: "client_language",
            value: "Portuguese"
        )
        let secondSave = try await repository.saveByKey(
            key: "client_language",
            value: "English"
        )

        XCTAssertEqual(secondSave.id, firstSave.id)

        let persistedMemories = try await repository.query(
            matching: ["key": "client_language"]
        )
        XCTAssertEqual(persistedMemories.count, 1)
        XCTAssertEqual(persistedMemories.first?.id, firstSave.id)
        XCTAssertEqual(persistedMemories.first?.value, "English")
    }
}
