import Foundation
@testable import AIAssistantHub

final class FirestoreFixtureBuilder {
    private var importedCollectionNames = Set<String>()

    let namespace: String
    let scope: FirebaseProfileScope

    init(scope: FirebaseProfileScope = .testScope()) {
        self.scope = scope
        self.namespace = scope.profileId
    }

    func loadFixture(named name: String) throws -> FirestoreFixture {
        try FirestoreFixture.load(named: name)
    }

    func importFixture(named name: String) async throws {
        let fixture = try loadFixture(named: name)
        importedCollectionNames.formUnion(fixture.collectionNames)
        try await fixture.importData(into: scope)
    }

    func clearFixture() async throws {
        try await scope.cleanup(collectionNames: importedCollectionNames)
        importedCollectionNames.removeAll()
    }

    func createIsolatedProfileScope() -> FirebaseProfileScope {
        scope
    }

    static func createIsolatedProfileScope(namespace: String = generateUniqueTestNamespace()) -> FirebaseProfileScope {
        FirebaseProfileScope(profileId: namespace)
    }

    static func generateUniqueTestNamespace() -> String {
        "test-\(UUID().uuidString.lowercased())"
    }
}
