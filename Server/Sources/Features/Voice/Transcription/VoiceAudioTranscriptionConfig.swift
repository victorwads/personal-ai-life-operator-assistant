import Foundation

enum VoiceVADMode: String, CaseIterable, Equatable {
    case timedTextActivity
    case localModel
}

struct VoiceAudioTranscriptionConfig: Equatable {
    var silenceBreakInterval: TimeInterval
    var minimumSegmentDuration: TimeInterval
    var maximumSegmentDuration: TimeInterval
    var realtimeDebounceInterval: TimeInterval
    var enablesWhisperPostProcessing: Bool
    var commitsAppleTextWhenWhisperFails: Bool
    var appleSpeechLanguage: String
    var whisperLanguage: String
    var whisperTask: WhisperTranscriptionTask
    var enablesAppleSpeech: Bool

    var whisperModelPath: String?
    var whisperCoreMLModelPath: String?
    var whisperTranscriptionUsesCPUOnly: Bool
    var whisperTranscriptionCPUThreadCount: Int

    var vadMode: VoiceVADMode
    var vadModelPath: String?
    var vadThreshold: Double
    var vadMinSpeechDuration: TimeInterval
    var vadMinSilenceDuration: TimeInterval
    var vadNoTextFallbackInterval: TimeInterval
    var segmentAudioOverlapDuration: TimeInterval
    var paragraphBreakSilenceDuration: TimeInterval
    var enablesParagraphBreaks: Bool
    var debugMinimumPostProcessingDisplayDuration: TimeInterval?

    init(
        silenceBreakInterval: TimeInterval = 0.45,
        minimumSegmentDuration: TimeInterval = 0.35,
        maximumSegmentDuration: TimeInterval = 20,
        realtimeDebounceInterval: TimeInterval = 0.08,
        enablesWhisperPostProcessing: Bool = true,
        commitsAppleTextWhenWhisperFails: Bool = true,
        appleSpeechLanguage: String = "auto",
        whisperLanguage: String = "pt",
        whisperTask: WhisperTranscriptionTask = .transcribe,
        enablesAppleSpeech: Bool = true,
        whisperModelPath: String? = nil,
        whisperCoreMLModelPath: String? = nil,
        whisperTranscriptionUsesCPUOnly: Bool = false,
        whisperTranscriptionCPUThreadCount: Int = 2,
        vadMode: VoiceVADMode = .timedTextActivity,
        vadModelPath: String? = nil,
        vadThreshold: Double = 0.5,
        vadMinSpeechDuration: TimeInterval = 0.15,
        vadMinSilenceDuration: TimeInterval = 0.45,
        vadNoTextFallbackInterval: TimeInterval = 5.0,
        segmentAudioOverlapDuration: TimeInterval = 0.10,
        paragraphBreakSilenceDuration: TimeInterval = 4.0,
        enablesParagraphBreaks: Bool = true,
        debugMinimumPostProcessingDisplayDuration: TimeInterval? = nil
    ) {
        self.silenceBreakInterval = silenceBreakInterval
        self.minimumSegmentDuration = minimumSegmentDuration
        self.maximumSegmentDuration = maximumSegmentDuration
        self.realtimeDebounceInterval = realtimeDebounceInterval
        self.enablesWhisperPostProcessing = enablesWhisperPostProcessing
        self.commitsAppleTextWhenWhisperFails = commitsAppleTextWhenWhisperFails
        self.appleSpeechLanguage = appleSpeechLanguage
        self.whisperLanguage = whisperLanguage
        self.whisperTask = whisperTask
        self.enablesAppleSpeech = enablesAppleSpeech
        self.whisperModelPath = whisperModelPath
        self.whisperCoreMLModelPath = whisperCoreMLModelPath
        self.whisperTranscriptionUsesCPUOnly = whisperTranscriptionUsesCPUOnly
        self.whisperTranscriptionCPUThreadCount = whisperTranscriptionCPUThreadCount
        self.vadMode = vadMode
        self.vadModelPath = vadModelPath
        self.vadThreshold = vadThreshold
        self.vadMinSpeechDuration = vadMinSpeechDuration
        self.vadMinSilenceDuration = vadMinSilenceDuration
        self.vadNoTextFallbackInterval = vadNoTextFallbackInterval
        self.segmentAudioOverlapDuration = segmentAudioOverlapDuration
        self.paragraphBreakSilenceDuration = paragraphBreakSilenceDuration
        self.enablesParagraphBreaks = enablesParagraphBreaks
        self.debugMinimumPostProcessingDisplayDuration = debugMinimumPostProcessingDisplayDuration
    }

    static let `default` = VoiceAudioTranscriptionConfig()
}
