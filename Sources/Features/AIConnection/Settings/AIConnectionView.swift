import SwiftUI

struct AIConnectionSettingsView: View {
    let wrapper: AIConnectionSettingsWrapper

    @State private var baseURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Base URL", text: baseURLBinding)

            Text("Used later for the local AI provider connection.")
                .foregroundStyle(.secondary)
        }
        .task {
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
}
