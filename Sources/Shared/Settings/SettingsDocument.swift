import Foundation

struct SettingsDocument: Equatable, Sendable {
    let scopeName: String
    var values: [String: String]

    init(scopeName: String, values: [String: String] = [:]) {
        self.scopeName = scopeName
        self.values = values
    }
}
