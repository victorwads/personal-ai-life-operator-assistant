import Foundation

struct WhisperPostProcessingConfig: Sendable {
    var isEnabled: Bool = false
    var modelPath: String?
    var coreMLModelPath: String?
    var language: String = "auto"
}
