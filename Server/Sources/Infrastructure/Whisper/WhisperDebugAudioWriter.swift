import Foundation
import WhisperCPP

enum WhisperDebugAudioWriter {
    static func writeTemporaryWAV(samples: [Float], prefix: String = "whisper-debug") -> String? {
        guard !samples.isEmpty else {
            return nil
        }

        let filename = "\(prefix)-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).wav"

        do {
            let directoryURL = try debugAudioDirectoryURL()
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let url = directoryURL.appendingPathComponent(filename, isDirectory: false)
            let data = try wavData(samples: samples)
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            print("[SpeechListener] Failed to write Whisper debug WAV: \(error)")
            return nil
        }
    }

    private static func debugAudioDirectoryURL() throws -> URL {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw WhisperDebugAudioWriterError.applicationSupportUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent("AIAssistantHub", isDirectory: true)
            .appendingPathComponent("ClientVoice", isDirectory: true)
            .appendingPathComponent("WhisperDebugAudio", isDirectory: true)
    }

    private static func wavData(samples: [Float]) throws -> Data {
        let pcmSamples = samples.map { sample -> Int16 in
            let clamped = max(-1.0 as Float, min(1.0 as Float, sample))
            return Int16(clamped * Float(Int16.max))
        }

        let bytesPerSample = MemoryLayout<Int16>.size
        let dataChunkSize = pcmSamples.count * bytesPerSample
        let riffChunkSize = 36 + dataChunkSize

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(UInt32(riffChunkSize), to: &data)
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16, to: &data)
        appendUInt16(1, to: &data)
        appendUInt16(1, to: &data)
        appendUInt32(UInt32(WHISPER_SAMPLE_RATE), to: &data)
        appendUInt32(UInt32(WHISPER_SAMPLE_RATE * 2), to: &data)
        appendUInt16(2, to: &data)
        appendUInt16(16, to: &data)

        data.append(contentsOf: Array("data".utf8))
        appendUInt32(UInt32(dataChunkSize), to: &data)
        pcmSamples.forEach { appendInt16($0, to: &data) }
        return data
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { buffer in
            data.append(buffer.bindMemory(to: UInt8.self))
        }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { buffer in
            data.append(buffer.bindMemory(to: UInt8.self))
        }
    }

    private static func appendInt16(_ value: Int16, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { buffer in
            data.append(buffer.bindMemory(to: UInt8.self))
        }
    }
}

private enum WhisperDebugAudioWriterError: Error {
    case applicationSupportUnavailable
}
