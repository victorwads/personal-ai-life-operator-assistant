import Foundation

struct ListenConfig: Sendable {
    var language: String = "auto"
    var debounceFinalMs: Int = 1200
    var postProcessing: WhisperPostProcessingConfig?
}
