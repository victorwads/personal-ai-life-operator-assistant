import SwiftUI

struct AssistantMCPServerCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Show Profiles Window") {
                ProfileWindowManager.shared.showHomeWindow()
            }
        }

        CommandGroup(after: .windowList) {
            Button("Show All Managed Windows") {
                ProfileWindowManager.shared.showAllManagedWindows()
            }
        }
    }
}
