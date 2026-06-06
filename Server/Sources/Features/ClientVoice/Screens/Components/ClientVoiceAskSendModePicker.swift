import SwiftUI

struct ClientVoiceAskSendModePicker: View {
    @Binding var selection: ClientVoiceAskSendMode

    var body: some View {
        Picker("Ask Response Mode", selection: $selection) {
            ForEach(ClientVoiceAskSendMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
