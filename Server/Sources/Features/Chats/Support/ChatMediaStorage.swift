import CommonCrypto
import Foundation

struct ChatMediaData {
    let data: Data
    let mimeType: String?
}

typealias ChatMediaImageData = ChatMediaData

enum ChatMediaStorage {
    static func mediaDirectoryURL(profileId: String, forMessageId messageId: String) -> URL {
        applicationSupportMediaRootURL(profileId: profileId)
            .appendingPathComponent(messageId, isDirectory: true)
    }

    static func existingRelativeMediaPaths(
        profileId: String,
        forMessageId messageId: String
    ) throws -> [String] {
        let directoryURL = mediaDirectoryURL(profileId: profileId, forMessageId: messageId)
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let mediaURLs = fileURLs
            .filter { supportedMediaExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        return mediaURLs.map(relativePath(for:))
    }

    static func saveImageData(
        _ imageItems: [ChatMediaImageData],
        profileId: String,
        forMessageId messageId: String
    ) throws -> [String] {
        try saveMediaData(imageItems, profileId: profileId, forMessageId: messageId)
    }

    static func saveAudioData(
        _ audioItems: [ChatMediaData],
        profileId: String,
        forMessageId messageId: String
    ) throws -> [String] {
        try saveMediaData(audioItems, profileId: profileId, forMessageId: messageId)
    }

    static func saveMediaData(
        _ mediaItems: [ChatMediaData],
        profileId: String,
        forMessageId messageId: String
    ) throws -> [String] {
        guard !mediaItems.isEmpty else { return [] }

        let directoryURL = mediaDirectoryURL(profileId: profileId, forMessageId: messageId)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        var relativePaths: [String] = []
        for mediaItem in mediaItems {
            let fileExtension = fileExtension(for: mediaItem.mimeType)
            let hash = md5Hex(of: mediaItem.data)
            let fileURL = directoryURL.appendingPathComponent("\(hash).\(fileExtension)", isDirectory: false)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let existingData = try? Data(contentsOf: fileURL),
               existingData == mediaItem.data {
                relativePaths.append(relativePath(for: fileURL))
                continue
            }

            try mediaItem.data.write(to: fileURL, options: .atomic)
            relativePaths.append(relativePath(for: fileURL))
        }
        return relativePaths
    }

    static func absoluteURL(forRelativePath relativePath: String) -> URL {
        applicationSupportRootURL().appendingPathComponent(relativePath, isDirectory: false)
    }

    private static func applicationSupportMediaRootURL(profileId: String) -> URL {
        applicationSupportURL(profileId: profileId).appendingPathComponent("Media", isDirectory: true)
    }

    private static func applicationSupportURL(profileId: String) -> URL {
        applicationSupportRootURL()
            .appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(profileId, isDirectory: true)
    }

    private static func applicationSupportRootURL() -> URL {
        guard let rootURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("Application Support directory is unavailable.")
        }
        return rootURL
            .appendingPathComponent("AIAssistantHub", isDirectory: true)
    }

    private static func relativePath(for fileURL: URL) -> String {
        let components = fileURL.pathComponents
        if let profilesIndex = components.lastIndex(of: "Profiles") {
            return components[profilesIndex...].joined(separator: "/")
        }
        guard let mediaIndex = components.lastIndex(of: "Media") else {
            return fileURL.lastPathComponent
        }
        return components[mediaIndex...].joined(separator: "/")
    }

    private static func fileExtension(for mimeType: String?) -> String {
        switch mimeType?.lowercased() {
        case "image/jpeg", "image/jpg":
            return "jpg"
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/webp":
            return "webp"
        case let value? where value.hasPrefix("audio/ogg"):
            return "ogg"
        default:
            return "png"
        }
    }

    private static func md5Hex(of data: Data) -> String {
        let digest = data.withUnsafeBytes { buffer in
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
            return digest
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static let supportedMediaExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "ogg"]
}
