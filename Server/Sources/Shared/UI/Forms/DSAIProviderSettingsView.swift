import SwiftUI

struct DSAIProviderSettingsView: View {
    @Binding var settings: AIProviderSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DSSettingsTextField(
                title: "Base URL",
                prompt: "e.g., https://api.openai.com/v1",
                helperText: "The API endpoint URL for this provider.",
                text: $settings.baseURL
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline.weight(.semibold))
                SecureField("Enter API Key", text: $settings.apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            DSSettingsTextField(
                title: "Model",
                prompt: "e.g., gpt-4o",
                helperText: "The exact identifier of the model to use.",
                text: $settings.model
            )

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reasoning Effort")
                        .font(.subheadline.weight(.semibold))
                    Picker("", selection: $settings.reasoningEffort) {
                        ForEach(AIConnectionReasoningEffort.allCases, id: \.self) { effort in
                            Text(effort.displayName).tag(effort)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Cache Mode")
                        .font(.subheadline.weight(.semibold))
                    Picker("", selection: $settings.cacheMode) {
                        ForEach(AIConnectionCacheMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
