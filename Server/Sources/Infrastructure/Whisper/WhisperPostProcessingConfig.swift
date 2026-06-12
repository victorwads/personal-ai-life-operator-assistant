import Foundation

enum WhisperTranscriptionTask: String, CaseIterable, Equatable, Sendable {
    case transcribe
    case translate
}

struct WhisperPostProcessingConfig: Sendable {
    var isEnabled: Bool = false
    var modelPath: String?
    var coreMLModelPath: String?
    var usesCPUOnly: Bool = false
    var cpuThreadCount: Int = 2
    var language: String = "auto"
    var task: WhisperTranscriptionTask = .transcribe

    init(
        isEnabled: Bool = false,
        modelPath: String? = nil,
        coreMLModelPath: String? = nil,
        usesCPUOnly: Bool = false,
        cpuThreadCount: Int = 2,
        language: String = "auto",
        task: WhisperTranscriptionTask = .transcribe
    ) {
        self.isEnabled = isEnabled
        self.modelPath = modelPath
        self.coreMLModelPath = coreMLModelPath
        self.usesCPUOnly = usesCPUOnly
        self.cpuThreadCount = cpuThreadCount
        self.language = language
        self.task = task
    }
}
