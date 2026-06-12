import AVFoundation
import Foundation

final class VoiceLocalModelVAD: VoiceActivityDetecting {
    var onSpeechStarted: (() -> Void)?
    var onSpeechEnded: (() -> Void)?

    private let config: VoiceAudioTranscriptionConfig
    private var vad: WhisperCppVAD?
    
    private var isSpeaking = false
    private var speechStartTime: TimeInterval?
    private var silenceStartTime: TimeInterval?
    
    private var sampleBuffer = [Float]()
    private let targetSampleRate: Int = 16000
    // whisper.cpp VAD typical chunk size (e.g., 512 frames)
    private let chunkSize = 16000
    
    // We could use an AVAudioConverter if the input rate is not 16kHz
    // Assuming input is already float 16kHz mono as standard in whisper apps, or just passing it directly
    
    init(config: VoiceAudioTranscriptionConfig) throws {
        self.config = config

        guard let modelPath = config.vadModelPath, !modelPath.isEmpty else {
            throw VoiceVADError.missingModelPath
        }

        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw VoiceVADError.modelLoadFailed("VAD model file not found at path: \(modelPath)")
        }

        // Run isolated sanity self-test before starting the real VAD context
        try runSanitySelfTest(modelPath: modelPath)

        do {
            self.vad = try WhisperCppVAD(
                modelPath: modelPath,
                threshold: config.vadThreshold,
                minSpeechDuration: config.vadMinSpeechDuration,
                minSilenceDuration: config.vadMinSilenceDuration,
                nThreads: 2,
                useGPU: false,
                gpuDevice: 0
            )
        } catch {
            throw VoiceVADError.modelLoadFailed("Failed to initialize whisper.cpp VAD: \(error.localizedDescription)")
        }
    }

    private func runSanitySelfTest(modelPath: String) throws {
        print("[VoiceLocalModelVAD] Starting VAD sanity self-test...")
        
        // 1. Initialize WhisperCppVAD with useGPU = false
        print("[VoiceLocalModelVAD] Self-test init begin")
        let testVAD = try WhisperCppVAD(
            modelPath: modelPath,
            threshold: config.vadThreshold,
            minSpeechDuration: config.vadMinSpeechDuration,
            minSilenceDuration: config.vadMinSilenceDuration,
            nThreads: 2,
            useGPU: false,
            gpuDevice: 0
        )
        print("[VoiceLocalModelVAD] Self-test init success")
        
        // 2. Feed with 1 second of artificial silence: Array(repeating: 0, count: 16000)
        let silence1s = Array(repeating: Float(0.0), count: 16000)
        print("[VoiceLocalModelVAD] Self-test feeding 16000 samples")
        _ = testVAD.processNoReset(samples: silence1s)
        print("[VoiceLocalModelVAD] Self-test feeding 16000 samples success")
        
        // 3. Feed with chunks: 1600, 3200, 16000
        let chunk1600 = Array(repeating: Float(0.0), count: 1600)
        print("[VoiceLocalModelVAD] Self-test feeding 1600 samples")
        _ = testVAD.processNoReset(samples: chunk1600)
        print("[VoiceLocalModelVAD] Self-test feeding 1600 samples success")
        
        let chunk3200 = Array(repeating: Float(0.0), count: 3200)
        print("[VoiceLocalModelVAD] Self-test feeding 3200 samples")
        _ = testVAD.processNoReset(samples: chunk3200)
        print("[VoiceLocalModelVAD] Self-test feeding 3200 samples success")
        
        let chunk16000 = Array(repeating: Float(0.0), count: 16000)
        print("[VoiceLocalModelVAD] Self-test feeding another 16000 samples")
        _ = testVAD.processNoReset(samples: chunk16000)
        print("[VoiceLocalModelVAD] Self-test feeding another 16000 samples success")
        
        print("[VoiceLocalModelVAD] VAD sanity self-test passed successfully!")
    }

    func start() {
        isSpeaking = false
        speechStartTime = nil
        silenceStartTime = nil
        sampleBuffer.removeAll()
        vad?.reset()
    }

    func stop() {
        sampleBuffer.removeAll()
    }

    func reset() {
        start()
    }

    func processAudioSamples(_ samples: [Float]) {
        sampleBuffer.append(contentsOf: samples)
        
        // Feed audio chunks to VAD
        while sampleBuffer.count >= chunkSize {
            let chunk = Array(sampleBuffer.prefix(chunkSize))
            sampleBuffer.removeFirst(chunkSize)
            
            // For continuous streaming, use processNoReset
            if let vad = vad {
                _ = vad.processNoReset(samples: chunk)
            }
        }
        
        // If there's still a small chunk at the end, wait for more data.
        
        // Use the latest probability if needed, or just the returned boolean
        if let vad = vad, let prob = vad.latestProbabilities.last {
            handleProbability(Double(prob))
        }
    }
    
    private func handleProbability(_ prob: Double) {
        let now = Date().timeIntervalSince1970
        
        if prob >= config.vadThreshold {
            silenceStartTime = nil
            
            if !isSpeaking {
                if speechStartTime == nil {
                    speechStartTime = now
                }
                if now - (speechStartTime ?? now) >= config.vadMinSpeechDuration {
                    isSpeaking = true
                    onSpeechStarted?()
                }
            }
        } else {
            speechStartTime = nil
            
            if isSpeaking {
                if silenceStartTime == nil {
                    silenceStartTime = now
                }
                if now - (silenceStartTime ?? now) >= config.vadMinSilenceDuration {
                    isSpeaking = false
                    onSpeechEnded?()
                    
                    // Reset VAD state between utterances? 
                    // As per user instructions: "Call whisper_vad_reset_state between utterances/segments."
                    vad?.reset()
                }
            }
        }
    }
    
    var latestProbability: Float? {
        return vad?.latestProbabilities.last
    }
}

enum VoiceVADError: LocalizedError {
    case missingModelPath
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingModelPath:
            return "VAD model path is required when using local VAD model mode."
        case .modelLoadFailed(let message):
            return "Failed to load VAD model: \(message)"
        }
    }
}
