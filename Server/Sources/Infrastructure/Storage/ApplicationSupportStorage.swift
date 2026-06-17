import Foundation

enum ApplicationSupportStorage {
    static let applicationName = "AIAssistantHub"

    static func appSupportDirectoryURL(
        appending components: [String] = []
    ) -> URL {
        guard let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            preconditionFailure("Application Support directory is unavailable.")
        }

        return components.reduce(
            baseURL.appendingPathComponent(applicationName, isDirectory: true)
        ) { partialURL, component in
            partialURL.appendingPathComponent(component, isDirectory: true)
        }
    }
}
