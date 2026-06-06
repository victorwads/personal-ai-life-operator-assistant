import AVFoundation
import Foundation
import WhisperCPP

struct CapturedSpeechAudioDiagnostics: Sendable {
    let inputSampleRate: Double
    let inputChannelCount: AVAudioChannelCount
    let outputSampleRate: Double
    let outputChannelCount: AVAudioChannelCount
    let appendCount: Int
    let inputFrameCount: Int
    let outputFrameCount: Int
    let peakAmplitude: Float
    let averageAbsoluteAmplitude: Float

    var outputDurationSeconds: Double {
        guard outputSampleRate > 0 else { return 0 }
        return Double(outputFrameCount) / outputSampleRate
    }

    var summary: String {
        "input=\(format(inputSampleRate))Hz/\(inputChannelCount)ch, " +
            "output=\(format(outputSampleRate))Hz/\(outputChannelCount)ch, " +
            "appends=\(appendCount), inputFrames=\(inputFrameCount), " +
            "outputFrames=\(outputFrameCount), duration=\(format(outputDurationSeconds))s, " +
            "peak=\(format(Double(peakAmplitude))), avgAbs=\(format(Double(averageAbsoluteAmplitude)))"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

final class CapturedSpeechAudioBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let inputFormat: AVAudioFormat
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private var samples: [Float] = []
    private var appendCount = 0
    private var inputFrameCount = 0

    init(inputFormat: AVAudioFormat) throws {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(WHISPER_SAMPLE_RATE),
            channels: 1,
            interleaved: false
        ) else {
            throw CapturedSpeechAudioBufferError.outputFormatUnavailable
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw CapturedSpeechAudioBufferError.converterUnavailable
        }

        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        self.converter = converter

        print("[SpeechListener] Whisper audio capture configured: input=\(inputFormatDescription(inputFormat)), output=\(inputFormatDescription(outputFormat))")
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        appendCount += 1
        inputFrameCount += Int(buffer.frameLength)

        let outputFrameCount = max(
            AVAudioFrameCount(1),
            AVAudioFrameCount(
                ceil(Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate)
            ) + 32
        )

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCount
        ) else {
            print("[SpeechListener] Failed to allocate Whisper capture conversion buffer.")
            return
        }

        var providedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
            if providedInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            providedInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let conversionError {
            print("[SpeechListener] Failed to capture audio for Whisper post-processing: \(conversionError)")
            return
        }

        guard status == .haveData || status == .inputRanDry || status == .endOfStream else {
            print("[SpeechListener] Whisper capture converter returned unexpected status: \(status.rawValue)")
            return
        }

        guard
            convertedBuffer.frameLength > 0,
            let channelData = convertedBuffer.floatChannelData?.pointee
        else {
            return
        }

        samples.append(contentsOf: UnsafeBufferPointer(
            start: channelData,
            count: Int(convertedBuffer.frameLength)
        ))
    }

    func takeAllSamples() -> (samples: [Float], diagnostics: CapturedSpeechAudioDiagnostics) {
        lock.lock()
        defer { lock.unlock() }

        let currentSamples = samples
        let diagnostics = makeDiagnostics(samples: currentSamples)
        samples.removeAll(keepingCapacity: false)
        appendCount = 0
        inputFrameCount = 0
        return (currentSamples, diagnostics)
    }

    func reset() {
        lock.lock()
        samples.removeAll(keepingCapacity: false)
        appendCount = 0
        inputFrameCount = 0
        lock.unlock()
    }

    private func makeDiagnostics(samples: [Float]) -> CapturedSpeechAudioDiagnostics {
        var peak: Float = 0
        var absoluteSum: Double = 0

        for sample in samples {
            let absoluteValue = abs(sample)
            peak = max(peak, absoluteValue)
            absoluteSum += Double(absoluteValue)
        }

        let averageAbsoluteAmplitude = samples.isEmpty ? 0 : Float(absoluteSum / Double(samples.count))

        return CapturedSpeechAudioDiagnostics(
            inputSampleRate: inputFormat.sampleRate,
            inputChannelCount: inputFormat.channelCount,
            outputSampleRate: outputFormat.sampleRate,
            outputChannelCount: outputFormat.channelCount,
            appendCount: appendCount,
            inputFrameCount: inputFrameCount,
            outputFrameCount: samples.count,
            peakAmplitude: peak,
            averageAbsoluteAmplitude: averageAbsoluteAmplitude
        )
    }

    private func inputFormatDescription(_ format: AVAudioFormat) -> String {
        "\(format.sampleRate)Hz/\(format.channelCount)ch/\(format.commonFormat)"
    }
}

enum CapturedSpeechAudioBufferError: Error {
    case converterUnavailable
    case outputFormatUnavailable
}
