import SwiftUI

struct WhatsAppNativeSettingsView: View {
    let wrapper: WhatsAppNativeSettingsWrapper

    @State private var enabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enabled", isOn: enabledBinding)
            Text("Accessibility runtime settings will be added here later.")
                .foregroundStyle(.secondary)
        }
        .task {
            enabled = wrapper.enabled
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding {
            enabled
        } set: { value in
            enabled = value
            wrapper.enabled = value
        }
    }
}
