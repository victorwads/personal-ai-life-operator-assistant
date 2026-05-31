import SwiftUI

struct AIConnectionSettingsView: View {
    let wrapper: AIConnectionSettingsWrapper

    @State private var autoStart = false
    @State private var providerKind = AIConnectionProviderKind.openRouter
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var temperature = 0.7
    @State private var maxOutputTokens = ""
    @State private var cacheMode = AIConnectionCacheMode.automatic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Auto Start AI Connection", isOn: autoStartBinding)
            Picker("Provider", selection: providerKindBinding) {
                ForEach(AIConnectionProviderKind.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            TextField("Base URL", text: baseURLBinding)
                .autocorrectionDisabled()
            SecureField("API Key", text: apiKeyBinding)
            TextField("Model", text: modelBinding)
                .autocorrectionDisabled()
            Stepper(
                "Temperature: \(temperature, specifier: "%.1f")",
                value: temperatureBinding,
                in: 0...2,
                step: 0.1
            )
            TextField("Max Output Tokens (optional)", text: maxOutputTokensBinding)
                .autocorrectionDisabled()
            Picker("Cache Mode", selection: cacheModeBinding) {
                ForEach(AIConnectionCacheMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Text("Streaming is always used. Cache behavior depends on the selected provider.")
                .foregroundStyle(.secondary)
        }
        .task {
            load()
        }
    }

    private var autoStartBinding: Binding<Bool> {
        Binding {
            autoStart
        } set: { value in
            autoStart = value
            wrapper.autoStart = value
        }
    }

    private var providerKindBinding: Binding<AIConnectionProviderKind> {
        Binding {
            providerKind
        } set: { value in
            providerKind = value
            wrapper.providerKind = value
            baseURL = wrapper.baseURL
        }
    }

    private var baseURLBinding: Binding<String> {
        Binding {
            baseURL
        } set: { value in
            baseURL = value
            wrapper.baseURL = value
        }
    }

    private var apiKeyBinding: Binding<String> {
        Binding {
            apiKey
        } set: { value in
            apiKey = value
            wrapper.apiKey = value
        }
    }

    private var modelBinding: Binding<String> {
        Binding {
            model
        } set: { value in
            model = value
            wrapper.model = value
        }
    }

    private var temperatureBinding: Binding<Double> {
        Binding {
            temperature
        } set: { value in
            let normalizedValue = min(max(value, 0), 2)
            temperature = normalizedValue
            wrapper.temperature = normalizedValue
        }
    }

    private var maxOutputTokensBinding: Binding<String> {
        Binding {
            maxOutputTokens
        } set: { value in
            maxOutputTokens = value
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            wrapper.maxOutputTokens = Int(trimmedValue)
        }
    }

    private var cacheModeBinding: Binding<AIConnectionCacheMode> {
        Binding {
            cacheMode
        } set: { value in
            cacheMode = value
            wrapper.cacheMode = value
        }
    }

    private func load() {
        autoStart = wrapper.autoStart
        providerKind = wrapper.providerKind
        baseURL = wrapper.baseURL
        apiKey = wrapper.apiKey
        model = wrapper.model
        temperature = wrapper.temperature
        maxOutputTokens = wrapper.maxOutputTokens.map(String.init) ?? ""
        cacheMode = wrapper.cacheMode
    }
}
