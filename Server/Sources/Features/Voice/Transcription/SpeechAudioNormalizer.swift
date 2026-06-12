import AVFoundation
import Foundation

final class SpeechAudioNormalizer {
    private var converter: AVAudioConverter?
    private var cachedInputFormat: AVAudioFormat?
    private var outputFormat: AVAudioFormat?

    func normalize(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        let inputFormat = buffer.format
        
        if converter == nil || cachedInputFormat != inputFormat {
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000.0,
                channels: 1,
                interleaved: false
            ) else {
                throw AudioNormalizerError.outputFormatUnavailable
            }
            
            guard let newConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw AudioNormalizerError.converterUnavailable
            }
            
            self.converter = newConverter
            self.outputFormat = targetFormat
            self.cachedInputFormat = inputFormat
        }
        
        guard let converter = converter, let outputFormat = outputFormat else {
            throw AudioNormalizerError.converterUnavailable
        }
        
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
            throw AudioNormalizerError.bufferAllocationFailed
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
            throw conversionError
        }
        
        guard status == .haveData || status == .inputRanDry || status == .endOfStream else {
            throw AudioNormalizerError.conversionFailed(status.rawValue)
        }
        
        guard convertedBuffer.frameLength > 0,
              let channelData = convertedBuffer.floatChannelData?.pointee else {
            return []
        }
        
        return Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
    }
}

enum AudioNormalizerError: LocalizedError {
    case converterUnavailable
    case outputFormatUnavailable
    case bufferAllocationFailed
    case conversionFailed(Int)
    
    var errorDescription: String? {
        switch self {
        case .converterUnavailable:
            return "Failed to create AVAudioConverter for sample rate conversion."
        case .outputFormatUnavailable:
            return "Failed to create 16kHz float mono output audio format."
        case .bufferAllocationFailed:
            return "Failed to allocate memory for converted audio buffer."
        case .conversionFailed(let code):
            return "Audio conversion failed with status code \(code)."
        }
    }
}
