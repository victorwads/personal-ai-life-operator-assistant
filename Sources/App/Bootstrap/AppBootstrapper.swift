import Foundation
import FirebaseCore

enum AppBootstrapper {
    static func configureFirebaseIfNeeded() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    static func validateFirebaseConfigured() {
        guard FirebaseApp.app() != nil else {
            fatalError("Firebase failed to configure. Ensure GoogleService-Info.plist is included in the app bundle Resources.")
        }
    }
}
