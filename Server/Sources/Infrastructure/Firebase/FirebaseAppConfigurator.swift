import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import Foundation

public enum FirebaseAppConfigurator {
    private static let emulatorFlagValues = Set(["1", "true", "yes", "on"])
    private static var firestoreConfigured = false

    public static func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        configureAuth()
        configureFirestore()
        configureRealtimeDatabase()
    }

    private static func configureFirestore() {
        guard !firestoreConfigured else {
            return
        }

        let firestore = Firestore.firestore()
        let settings = firestore.settings
        
        if RuntimeEnvironment.isTestingRuntime {
            settings.host = "localhost:4010"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            firestore.settings = settings
            firestoreConfigured = true
            return
        }

        if let emulator = emulatorEnvironment() {
            settings.host = "\(emulator.host):\(emulator.firestore)"
            settings.isSSLEnabled = false
            print("Firestore emulator configured at \(emulator.host):\(emulator.firestore).")
        }

        settings.cacheSettings = PersistentCacheSettings()
        firestore.settings = settings
        firestoreConfigured = true
        print("Firestore local persistence configured.")

        if let indexManager = firestore.persistentCacheIndexManager {
            indexManager.enableIndexAutoCreation()
        } else {
            print("Firestore persistent cache index manager unavailable; remote composite indexes are still required for server/default reads.")
        }
    }

    private static func configureRealtimeDatabase() {
        if RuntimeEnvironment.isTestingRuntime { return }
        guard let emulator = emulatorEnvironment() else {
            return
        }

        Database.database().useEmulator(withHost: emulator.host, port: emulator.database)
        print("Realtime Database emulator configured at \(emulator.host):\(emulator.database).")
    }

    private static func configureAuth() {
        if RuntimeEnvironment.isTestingRuntime { return }
        guard let emulator = emulatorEnvironment() else {
            return
        }

        Auth.auth().useEmulator(withHost: emulator.host, port: emulator.auth)
        print("Firebase Auth emulator enabled at \(emulator.host):\(emulator.auth).")
    }

    private static func emulatorEnvironment() -> (host: String, firestore: Int, auth: Int, database: Int)? {
        
        let environment = ProcessInfo.processInfo.environment
        let useEmulatorRaw = environment["FIREBASE_USE_EMULATORS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "1"
        let enabled = emulatorFlagValues.contains(useEmulatorRaw)

        guard enabled else {
            return nil
        }

        let hostValue = environment["FIREBASE_EMULATOR_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = hostValue.isEmpty ? "localhost" : hostValue

        let firestore = Int(environment["FIRESTORE_EMULATOR_PORT"] ?? "") ?? 8080
        let auth = Int(environment["FIREBASE_AUTH_EMULATOR_PORT"] ?? "") ?? 9099
        let database = Int(environment["FIREBASE_DATABASE_EMULATOR_PORT"] ?? "") ?? 9000
        return (host: host, firestore: firestore, auth: auth, database: database)
    }
}
