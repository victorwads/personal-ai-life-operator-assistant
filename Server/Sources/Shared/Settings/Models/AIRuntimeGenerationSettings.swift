import Foundation

public struct AIRuntimeGenerationSettings: Equatable, Codable, Sendable {
    public var temperature: Double
    public var topP: Double
    public var topK: Int
    public var maxTokens: Int
    public var maxContextTokens: Int
    public var streamOutputEnabled: Bool
    public var showPerformanceMetrics: Bool
    public var kvCacheEnabled: Bool
    public var kvCacheQuantizationEnabled: Bool
    public var kvBits: Int
    public var kvGroupSize: Int
    public var quantizedKVStart: Int
    public var reasoningEnabled: Bool
    public var reasoningTokensLimit: Int
    public var selectedPreset: AIRuntimePreset

    public init(
        temperature: Double,
        topP: Double,
        topK: Int,
        maxTokens: Int,
        maxContextTokens: Int,
        streamOutputEnabled: Bool,
        showPerformanceMetrics: Bool,
        kvCacheEnabled: Bool,
        kvCacheQuantizationEnabled: Bool,
        kvBits: Int,
        kvGroupSize: Int,
        quantizedKVStart: Int,
        reasoningEnabled: Bool,
        reasoningTokensLimit: Int,
        selectedPreset: AIRuntimePreset
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
        self.maxContextTokens = maxContextTokens
        self.streamOutputEnabled = streamOutputEnabled
        self.showPerformanceMetrics = showPerformanceMetrics
        self.kvCacheEnabled = kvCacheEnabled
        self.kvCacheQuantizationEnabled = kvCacheQuantizationEnabled
        self.kvBits = kvBits
        self.kvGroupSize = kvGroupSize
        self.quantizedKVStart = quantizedKVStart
        self.reasoningEnabled = reasoningEnabled
        self.reasoningTokensLimit = reasoningTokensLimit
        self.selectedPreset = selectedPreset
    }

    public static var defaultSettings: AIRuntimeGenerationSettings {
        var settings = AIRuntimeGenerationSettings(
            temperature: 0.8,
            topP: 0.95,
            topK: 40,
            maxTokens: 4096,
            maxContextTokens: 8192,
            streamOutputEnabled: true,
            showPerformanceMetrics: true,
            kvCacheEnabled: true,
            kvCacheQuantizationEnabled: false,
            kvBits: 8,
            kvGroupSize: 64,
            quantizedKVStart: 0,
            reasoningEnabled: false,
            reasoningTokensLimit: 1024,
            selectedPreset: .balanced
        )
        AIRuntimePreset.balanced.apply(to: &settings)
        return settings
    }
}
