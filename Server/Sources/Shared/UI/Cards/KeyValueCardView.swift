import SwiftUI

struct KeyValueCardRow: Equatable {
    let key: String
    let value: String

    init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }
}

struct KeyValueCardView: View {
    let title: String?
    let rows: [KeyValueCardRow]

    init(title: String? = nil, rows: [KeyValueCardRow]) {
        self.title = title
        self.rows = rows
    }

    init(title: String? = nil, key: String, value: String) {
        self.title = title
        self.rows = [KeyValueCardRow(key, value)]
    }

    var body: some View {
        DSCard(title: title) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    rowView(row)
                }
            }
        }
    }

    private func rowView(_ row: KeyValueCardRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.key.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(row.value)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}
