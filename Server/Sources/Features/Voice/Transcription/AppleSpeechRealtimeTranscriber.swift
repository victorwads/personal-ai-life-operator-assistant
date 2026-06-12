import Foundation
import Speech
import AVFoundation

final class AppleSpeechRealtimeTranscriber: @unchecked Sendable {
    struct Event {
        enum Kind {
            case partial(String)
            case final(String)
            case error(String)
        }

        let kind: Kind
    }

    private let lock = NSLock()
    private var continuation: AsyncStream<Event>.Continuation?
    
    var onAudioBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?
    
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var recognitionGeneration: Int = 0
    private var intentionallyResetting = false
    
    lazy var events: AsyncStream<Event> = {
        AsyncStream { continuation in
            self.lock.lock()
            self.continuation = continuation
            self.lock.unlock()
        }
    }()
    
    init(language: String = "auto") {
        let locale: Locale
        if language == "auto" {
            locale = Locale.current
        } else {
            locale = Locale(identifier: language)
        }
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    func start() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            let authorized = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    continuation.resume(returning: authStatus == .authorized)
                }
            }
            guard authorized else {
                yieldEvent(.error("Speech recognition unauthorized"))
                return
            }
        } else if status != .authorized {
            yieldEvent(.error("Speech recognition unauthorized"))
            return
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            yieldEvent(.error("Speech recognizer unavailable"))
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.recognitionRequest = request
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.onAudioBuffer?(buffer, time)
            self?.lock.lock()
            let req = self?.recognitionRequest
            self?.lock.unlock()
            req?.append(buffer)
        }
        
        let currentGen = nextGeneration()
        
        startRecognitionTask(with: request, using: recognizer, generation: currentGen)
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func nextGeneration() -> Int {
        lock.lock()
        defer { lock.unlock() }
        recognitionGeneration += 1
        return recognitionGeneration
    }
    
    private func startRecognitionTask(
        with request: SFSpeechAudioBufferRecognitionRequest,
        using recognizer: SFSpeechRecognizer,
        generation: Int
    ) {
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            
            self.lock.lock()
            let isCurrentGeneration = generation == self.recognitionGeneration
            let isIntentionalReset = self.intentionallyResetting
            self.lock.unlock()
            
            guard isCurrentGeneration else {
                return
            }
            
            if let result {
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    self.yieldEvent(.partial(text))
                    if result.isFinal {
                        self.yieldEvent(.final(text))
                    }
                }
            }
            
            if let error {
                let message = error.localizedDescription
                let nsError = error as NSError
                let isCancelError = nsError.code == 301 ||
                                    nsError.code == 203 ||
                                    nsError.domain.contains("Assistant") ||
                                    nsError.domain.contains("Speech") ||
                                    message.localizedCaseInsensitiveContains("canceled") ||
                                    message.localizedCaseInsensitiveContains("cancelled")
                
                if isIntentionalReset && isCancelError {
                    return
                }
                
                self.yieldEvent(.error(message))
            }
        }
    }
    
    func reset() {
        lock.lock()
        intentionallyResetting = true
        recognitionGeneration += 1
        let newGeneration = recognitionGeneration
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            intentionallyResetting = false
            lock.unlock()
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.recognitionRequest = request
        lock.unlock()
        
        startRecognitionTask(with: request, using: recognizer, generation: newGeneration)
        
        lock.lock()
        intentionallyResetting = false
        lock.unlock()
    }
    
    func stop() async {
        performStop()
    }
    
    private func performStop() {
        lock.lock()
        defer { lock.unlock() }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        continuation?.finish()
    }
    
    private func yieldEvent(_ kind: Event.Kind) {
        lock.lock()
        let cont = continuation
        lock.unlock()
        cont?.yield(Event(kind: kind))
    }
}
