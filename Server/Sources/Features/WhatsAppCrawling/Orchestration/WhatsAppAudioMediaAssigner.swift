import Foundation

enum WhatsAppAudioMediaAssigner {
    static func assignAudioMedia(
        to messages: [ChatMessage],
        capturedAudio: [WebViewCapturedMedia],
        profileId: String,
        log: (String) -> Void
    ) throws -> [ChatMessage] {
        let audioMessageIndices = messages.indices.filter { messages[$0].kind == .audio }
        guard !audioMessageIndices.isEmpty else {
            return messages
        }

        guard audioMessageIndices.count == capturedAudio.count else {
            log("Audio blob count mismatch audioMessages=\(audioMessageIndices.count) capturedAudio=\(capturedAudio.count); skipping audio association.")
            return messages
        }

        var enrichedMessages = messages
        for (messageIndex, audioBlob) in zip(audioMessageIndices, capturedAudio) {
            guard let messageId = enrichedMessages[messageIndex].id else {
                log("Audio message without id at index=\(messageIndex); skipping audio association for this cycle.")
                return messages
            }

            guard let data = Data(base64Encoded: audioBlob.base64) else {
                log("Failed decoding audio blob for messageId=\(messageId); skipping audio association for this cycle.")
                return messages
            }

            let relativePaths = try ChatMediaStorage.saveAudioData(
                [ChatMediaData(data: data, mimeType: audioBlob.mimeType)],
                profileId: profileId,
                forMessageId: messageId
            )
            enrichedMessages[messageIndex].localMediaPaths = relativePaths
        }

        log("Audio files saved count=\(audioMessageIndices.count)")
        return enrichedMessages
    }
}
