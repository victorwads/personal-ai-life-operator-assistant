import Foundation

enum ChatMediaStorage {
    static func mediaDirectoryURL(forMessageId messageId: String) -> URL {
        applicationSupportMediaRootURL()
            .appendingPathComponent(messageId, isDirectory: true)
    }

    static func existingRelativeMediaPaths(forMessageId messageId: String) throws -> [String] {
        let directoryURL = mediaDirectoryURL(forMessageId: messageId)
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let pngURLs = fileURLs
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        return pngURLs.map(relativePath(for:))
    }

    static func savePNGData(_ dataItems: [Data], forMessageId messageId: String) throws -> [String] {
        guard !dataItems.isEmpty else { return [] }

        let directoryURL = mediaDirectoryURL(forMessageId: messageId)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        var relativePaths: [String] = []
        for (index, data) in dataItems.enumerated() {
            let fileURL = directoryURL.appendingPathComponent("\(index).png", isDirectory: false)
            try data.write(to: fileURL, options: .atomic)
            relativePaths.append(relativePath(for: fileURL))
        }
        return relativePaths
    }

    static func absoluteURL(forRelativePath relativePath: String) -> URL {
        applicationSupportURL().appendingPathComponent(relativePath, isDirectory: false)
    }

    private static func applicationSupportMediaRootURL() -> URL {
        applicationSupportURL().appendingPathComponent("Media", isDirectory: true)
    }

    private static func applicationSupportURL() -> URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("Application Support directory is unavailable.")
        }
        return url
    }

    private static func relativePath(for fileURL: URL) -> String {
        let components = fileURL.pathComponents
        guard let mediaIndex = components.lastIndex(of: "Media") else {
            return fileURL.lastPathComponent
        }
        return components[mediaIndex...].joined(separator: "/")
    }
}
