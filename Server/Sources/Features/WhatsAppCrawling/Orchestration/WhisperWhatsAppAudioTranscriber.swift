import AVFoundation
import Foundation
import WhisperCPP

protocol WhatsAppAudioTranscribing: Sendable {
    func transcribeAudioFile(
        audioURL: URL,
        config: WhisperPostProcessingConfig
    ) async throws -> String
}

actor WhisperWhatsAppAudioTranscriber: WhatsAppAudioTranscribing {
    static let shared = WhisperWhatsAppAudioTranscriber()

    private let postProcessor = WhisperSpeechPostProcessor.shared

    func transcribeAudioFile(
        audioURL: URL,
        config: WhisperPostProcessingConfig
    ) async throws -> String {
        let samples = try Self.loadWhisperSamples(from: audioURL)

        let result = await postProcessor.resolveFinalText(
            appleSpeechText: "",
            capturedAudioSamples: samples,
            whisperConfig: config,
            cancellationToken: WhisperProcessingCancellationToken()
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadWhisperSamples(from audioURL: URL) throws -> [Float] {
        let inputFile = try AVAudioFile(forReading: audioURL)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(WHISPER_SAMPLE_RATE),
            channels: 1,
            interleaved: false
        ) else {
            throw WhatsAppAudioTranscriptionError.outputFormatUnavailable
        }

        guard let converter = AVAudioConverter(
            from: inputFile.processingFormat,
            to: outputFormat
        ) else {
            throw WhatsAppAudioTranscriptionError.converterUnavailable
        }

        let inputFrameCapacity = AVAudioFrameCount(inputFile.length)
        guard let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFile.processingFormat,
            frameCapacity: inputFrameCapacity
        ) else {
            throw WhatsAppAudioTranscriptionError.inputBufferUnavailable
        }

        try inputFile.read(into: inputBuffer)

        let outputFrameCapacity = AVAudioFrameCount(
            ceil(Double(inputBuffer.frameLength) * outputFormat.sampleRate / inputFile.processingFormat.sampleRate)
        ) + 32

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw WhatsAppAudioTranscriptionError.outputBufferUnavailable
        }

        var didProvideInput = false
        var conversionError: NSError?

        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let conversionError {
            throw conversionError
        }

        guard status == .haveData || status == .inputRanDry || status == .endOfStream else {
            throw WhatsAppAudioTranscriptionError.conversionFailed(status.rawValue)
        }

        guard
            outputBuffer.frameLength > 0,
            let channelData = outputBuffer.floatChannelData?.pointee
        else {
            throw WhatsAppAudioTranscriptionError.emptyAudio
        }

        return Array(
            UnsafeBufferPointer(
                start: channelData,
                count: Int(outputBuffer.frameLength)
            )
        )
    }
}

enum WhatsAppAudioTranscriptionError: Error {
    case outputFormatUnavailable
    case converterUnavailable
    case inputBufferUnavailable
    case outputBufferUnavailable
    case conversionFailed(Int)
    case emptyAudio
}
