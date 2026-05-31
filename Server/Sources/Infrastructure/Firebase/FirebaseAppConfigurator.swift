import FirebaseCore
import FirebaseFirestore
import Foundation

public enum FirebaseAppConfigurator {
    private static let configurationLock = NSLock()
    private static var didConfigure = false

    public static func configure() {
        configurationLock.lock()
        defer { configurationLock.unlock() }

        guard didConfigure == false else {
            return
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        configureFirestore()
        didConfigure = true
    }

    private static func configureFirestore() {
        let firestore = Firestore.firestore()
        let settings = firestore.settings

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
}
