import FirebaseFirestore
import XCTest
@testable import AIAssistantHub

final class FirestoreEnvironmentTests: XCTestCase {
    func testTestingRuntimeConfiguresEmulatorMemoryCacheAndReadWriteAccess() async throws {
        await FirestoreTestEnvironment.configure()

        XCTAssertTrue(RuntimeEnvironment.isTestingRuntime)

        let settings = Firestore.firestore().settings
        XCTAssertEqual(settings.host, "localhost:4010")
        XCTAssertFalse(settings.isSSLEnabled)
        XCTAssertTrue(String(describing: type(of: settings.cacheSettings)).contains("MemoryCacheSettings"))

        let scope = FirebaseProfileScope(profileId: "firestore-environment-\(UUID().uuidString.lowercased())")
        let collectionPath = FirestoreRepositoryPath
            .profileScoped(scope: scope, collection: "EnvironmentChecks")
            .collectionPath
        let firestore = Firestore.firestore()
        let document = firestore.collection(collectionPath).document("check")

        try await document.setData([
            "value": "ok",
            "_createdAt": Date(),
            "_updatedAt": Date()
        ])

        let snapshot = try await document.getDocument()
        XCTAssertEqual(snapshot.data()?["value"] as? String, "ok")

        try await document.delete()
    }
}
