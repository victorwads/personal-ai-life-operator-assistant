import Foundation
import WhisperCPP

final class WhisperCppVAD {
    private let vctx: OpaquePointer
    private let threshold: Float
    private let minSpeechDuration: TimeInterval
    private let minSilenceDuration: TimeInterval

    init(
        modelPath: String,
        threshold: Double,
        minSpeechDuration: TimeInterval,
        minSilenceDuration: TimeInterval,
        nThreads: Int = 2,
        useGPU: Bool = false,
        gpuDevice: Int = 0
    ) throws {
        self.threshold = Float(threshold)
        self.minSpeechDuration = minSpeechDuration
        self.minSilenceDuration = minSilenceDuration

        var params = whisper_vad_default_context_params()
        params.n_threads = Int32(nThreads)
        params.use_gpu = useGPU
        params.gpu_device = Int32(gpuDevice)

        print("[WhisperCppVAD] VAD init begin")
        guard let vctx = modelPath.withCString({ whisper_vad_init_from_file_with_params($0, params) }) else {
            print("[WhisperCppVAD] VAD init failed")
            throw VoiceVADError.modelLoadFailed("Failed to initialize whisper.cpp VAD context from \(modelPath)")
        }
        print("[WhisperCppVAD] VAD init success")

        self.vctx = vctx
    }

    deinit {
        whisper_vad_free(vctx)
    }

    func process(samples: [Float]) -> Bool {
        print("[WhisperCppVAD] VAD process begin samples=\(samples.count)")
        let result = samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            return whisper_vad_detect_speech(vctx, baseAddress, Int32(buffer.count))
        }
        print("[WhisperCppVAD] VAD process success")
        return result
    }

    func processNoReset(samples: [Float]) -> Bool {
        print("[WhisperCppVAD] VAD process begin samples=\(samples.count)")
        let result = samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return false }
            return whisper_vad_detect_speech_no_reset(vctx, baseAddress, Int32(buffer.count))
        }
        print("[WhisperCppVAD] VAD process success")
        return result
    }

    func reset() {
        print("[WhisperCppVAD] VAD reset begin")
        whisper_vad_reset_state(vctx)
        print("[WhisperCppVAD] VAD reset success")
    }

    var latestProbabilities: [Float] {
        let count = whisper_vad_n_probs(vctx)
        guard count > 0, let probsPtr = whisper_vad_probs(vctx) else {
            return []
        }
        let buffer = UnsafeBufferPointer(start: probsPtr, count: Int(count))
        return Array(buffer)
    }
}
