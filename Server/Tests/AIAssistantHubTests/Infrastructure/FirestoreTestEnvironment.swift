import FirebaseCore
import FirebaseFirestore
import XCTest
@testable import AIAssistantHub

enum FirestoreTestEnvironment {
    private actor State {
        private var isConfigured = false

        func configureIfNeeded() {
            guard !isConfigured else {
                return
            }

            FirebaseAppConfigurator.configure()

            let settings = Firestore.firestore().settings
            let host = settings.host.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertFalse(host.isEmpty, "Expected Firestore emulator host to be configured during tests.")
            XCTAssertFalse(settings.isSSLEnabled, "Expected Firestore emulator SSL to be disabled during tests.")

            isConfigured = true
        }
    }

    private static let state = State()

    static func configure() async {
        await state.configureIfNeeded()
    }
}
