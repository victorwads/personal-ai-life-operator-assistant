import SwiftUI

struct DSLocalAIRuntimeSettingsView: View {
    @Binding var settings: AIRuntimeGenerationSettings

    private var presetBinding: Binding<AIRuntimePreset> {
        Binding {
            settings.selectedPreset
        } set: { newPreset in
            newPreset.apply(to: &settings)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Configuration Preset")
                    .font(.subheadline.weight(.semibold))
                Picker("", selection: presetBinding) {
                    ForEach(AIRuntimePreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Divider()

            // 2. Generation Parameters
            VStack(alignment: .leading, spacing: 12) {
                Text("Generation Parameters")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Temperature")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.2f", settings.temperature))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.temperature, in: 0.0...2.0, step: 0.05)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Top P")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.2f", settings.topP))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.topP, in: 0.0...1.0, step: 0.01)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Top K")
                            .font(.subheadline)
                        Spacer()
                        Text("\(settings.topK)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.topK) },
                        set: { settings.topK = Int($0) }
                    ), in: 1.0...100.0, step: 1.0)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Max Output Tokens")
                            .font(.subheadline.weight(.medium))
                        TextField("Max Tokens", value: $settings.maxTokens, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Max Context Tokens")
                            .font(.subheadline.weight(.medium))
                        TextField("Max Context", value: $settings.maxContextTokens, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            Divider()

            // 3. UI and Output Controls
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Stream Output", isOn: $settings.streamOutputEnabled)
                Toggle("Show Performance Metrics", isOn: $settings.showPerformanceMetrics)
            }

            Divider()

            // 4. KV Cache Settings
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("KV Cache Optimization")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Toggle("", isOn: $settings.kvCacheEnabled)
                        .labelsHidden()
                }

                if settings.kvCacheEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Quantize KV Cache", isOn: $settings.kvCacheQuantizationEnabled)

                        if settings.kvCacheQuantizationEnabled {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Bits")
                                        .font(.caption.weight(.semibold))
                                    Picker("", selection: $settings.kvBits) {
                                        Text("4-bit").tag(4)
                                        Text("8-bit").tag(8)
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Group Size")
                                        .font(.caption.weight(.semibold))
                                    Picker("", selection: $settings.kvGroupSize) {
                                        Text("32").tag(32)
                                        Text("64").tag(64)
                                        Text("128").tag(128)
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Quantized Start Step")
                                    .font(.caption.weight(.semibold))
                                TextField("Start Step", value: $settings.quantizedKVStart, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding(.leading, 8)
                }
            }

            Divider()

            // 5. Reasoning / Thinking Settings
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable Reasoning / Thinking", isOn: $settings.reasoningEnabled)

                if settings.reasoningEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reasoning Tokens Limit")
                            .font(.caption.weight(.semibold))
                        TextField("Limit", value: $settings.reasoningTokensLimit, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }
}
