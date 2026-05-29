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
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    rowView(row)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
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
