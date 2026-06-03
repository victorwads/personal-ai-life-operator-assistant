import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import Foundation

public enum FirebaseAppConfigurator {
    private static let emulatorFlagValues = Set(["1", "true", "yes", "on"])

    public static func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        configureAuth()
        configureFirestore()
    }

    private static func configureFirestore() {
        let firestore = Firestore.firestore()
        let settings = firestore.settings

        if let emulator = emulatorEnvironment() {
            // Important: configure emulator host through Firestore settings before any runtime
            // interaction with the instance to avoid "settings can no longer be changed" errors.
            settings.host = "\(emulator.host):\(emulator.firestorePort)"
            settings.isSSLEnabled = false
            print("Firestore emulator configured at \(emulator.host):\(emulator.firestorePort).")
        }

        // Firestore uses a persistent local cache by default on Apple platforms with the current
        // SDK, but we still set PersistentCacheSettings explicitly so startup behavior is clear and
        // stays local-first unless we intentionally change it.
        //
        // Local persistence/cache enables offline behavior and cached reads across app launches.
        // Persistent cache indexes improve local filtered/cache-only query execution over already
        // cached documents. They do not replace remote Firestore composite indexes required for
        // server/default reads when Firestore enforces them.
        settings.cacheSettings = PersistentCacheSettings()
        firestore.settings = settings
        print("Firestore local persistence configured.")

        if let indexManager = firestore.persistentCacheIndexManager {
            indexManager.enableIndexAutoCreation()
        } else {
            print("Firestore persistent cache index manager unavailable; remote composite indexes are still required for server/default reads.")
        }
    }

    private static func configureAuth() {
        guard let emulator = emulatorEnvironment() else {
            return
        }

        Auth.auth().useEmulator(withHost: emulator.host, port: emulator.authPort)
        print("Firebase Auth emulator enabled at \(emulator.host):\(emulator.authPort).")
    }

    private static func emulatorEnvironment() -> (host: String, firestorePort: Int, authPort: Int)? {
        let environment = ProcessInfo.processInfo.environment
        let useEmulatorRaw = environment["FIREBASE_USE_EMULATORS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let enabled = emulatorFlagValues.contains(useEmulatorRaw)

        guard enabled else {
            return nil
        }

        let hostValue = environment["FIREBASE_EMULATOR_HOST"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let host = hostValue.isEmpty ? "localhost" : hostValue

        let firestorePort = Int(environment["FIRESTORE_EMULATOR_PORT"] ?? "") ?? 8080
        let authPort = Int(environment["FIREBASE_AUTH_EMULATOR_PORT"] ?? "") ?? 9099
        return (host: host, firestorePort: firestorePort, authPort: authPort)
    }
}
