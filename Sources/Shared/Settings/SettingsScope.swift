import Foundation

@MainActor
final class SettingsScope: Identifiable {
    let name: String
    private var values: [String: String]

    var id: String { name }

    init(_ name: String, values: [String: String] = [:]) {
        self.name = name
        self.values = values
    }

    func update(values: [String: String]) {
        self.values = values
    }

    func value(_ key: String) -> String? {
        values[key]
    }

    func string(_ key: String, default defaultValue: String? = nil) -> String? {
        values[key] ?? defaultValue
    }

    var snapshotValues: [String: String] {
        values
    }
}
