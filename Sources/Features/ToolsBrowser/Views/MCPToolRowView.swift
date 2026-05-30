import SwiftUI

struct MCPToolRowView: View {
    let entry: MCPToolBrowserEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.headline)
                        .lineLimit(1)

                    DSBadge(entry.group)
                }

                Text(entry.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !entry.traits.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.traits, id: \.rawValue) { trait in
                            DSBadge(trait.displayName)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
