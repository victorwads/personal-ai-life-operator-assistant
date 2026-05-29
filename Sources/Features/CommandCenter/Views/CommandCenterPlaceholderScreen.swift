import SwiftUI

struct CommandCenterPlaceholderScreen: View {
    let title: String
    let description: String

    var body: some View {
        FeatureScreenContainer(title: title, subtitle: description) {
            Spacer(minLength: 0)
        }
    }
}
