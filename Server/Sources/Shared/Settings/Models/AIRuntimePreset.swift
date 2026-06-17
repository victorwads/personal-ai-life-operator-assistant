import Foundation

public enum AIRuntimePreset: String, Codable, CaseIterable, Sendable {
    case balanced = "Balanced"
    case fastest = "Fastest"
    case quality = "Quality"
    case longContext = "Long Context"
    case experimental = "Experimental"

    public var displayName: String { rawValue }

    public func apply(to settings: inout AIRuntimeGenerationSettings) {
        settings.selectedPreset = self
        switch self {
        case .balanced:
            settings.temperature = 0.8
            settings.topP = 0.95
            settings.topK = 40
            settings.maxTokens = 4096
            settings.maxContextTokens = 8192
            settings.streamOutputEnabled = true
            settings.kvCacheEnabled = true
            settings.kvCacheQuantizationEnabled = false
            settings.kvBits = 8
            settings.kvGroupSize = 64
            settings.quantizedKVStart = 0
            settings.reasoningEnabled = false
            settings.reasoningTokensLimit = 1024
        case .fastest:
            settings.temperature = 0.6
            settings.topP = 0.9
            settings.topK = 30
            settings.maxTokens = 2048
            settings.maxContextTokens = 4096
            settings.streamOutputEnabled = true
            settings.kvCacheEnabled = true
            settings.kvCacheQuantizationEnabled = true
            settings.kvBits = 4
            settings.kvGroupSize = 32
            settings.quantizedKVStart = 0
            settings.reasoningEnabled = false
            settings.reasoningTokensLimit = 512
        case .quality:
            settings.temperature = 0.7
            settings.topP = 0.98
            settings.topK = 50
            settings.maxTokens = 4096
            settings.maxContextTokens = 16384
            settings.streamOutputEnabled = true
            settings.kvCacheEnabled = true
            settings.kvCacheQuantizationEnabled = false
            settings.kvBits = 8
            settings.kvGroupSize = 64
            settings.quantizedKVStart = 0
            settings.reasoningEnabled = true
            settings.reasoningTokensLimit = 2048
        case .longContext:
            settings.temperature = 0.8
            settings.topP = 0.95
            settings.topK = 40
            settings.maxTokens = 8192
            settings.maxContextTokens = 32768
            settings.streamOutputEnabled = true
            settings.kvCacheEnabled = true
            settings.kvCacheQuantizationEnabled = true
            settings.kvBits = 8
            settings.kvGroupSize = 64
            settings.quantizedKVStart = 1024
            settings.reasoningEnabled = false
            settings.reasoningTokensLimit = 1024
        case .experimental:
            settings.temperature = 1.0
            settings.topP = 0.99
            settings.topK = 100
            settings.maxTokens = 4096
            settings.maxContextTokens = 8192
            settings.streamOutputEnabled = true
            settings.kvCacheEnabled = true
            settings.kvCacheQuantizationEnabled = true
            settings.kvBits = 4
            settings.kvGroupSize = 64
            settings.quantizedKVStart = 512
            settings.reasoningEnabled = true
            settings.reasoningTokensLimit = 1024
        }
    }
}
