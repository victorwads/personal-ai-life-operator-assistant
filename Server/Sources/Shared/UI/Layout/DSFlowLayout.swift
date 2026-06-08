import SwiftUI

struct DSFlowLayout: Layout {
    enum Alignment {
        case leading
        case center
        case trailing
    }

    let alignment: Alignment
    let spacing: CGFloat
    let rowSpacing: CGFloat

    init(alignment: Alignment = .leading, spacing: CGFloat = 8, rowSpacing: CGFloat = 8) {
        self.alignment = alignment
        self.spacing = spacing
        self.rowSpacing = rowSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        makeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let layout = makeLayout(
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height),
            subviews: subviews
        )

        for row in layout.rows {
            let xOffset: CGFloat
            switch alignment {
            case .leading:
                xOffset = 0
            case .center:
                xOffset = max(0, (bounds.width - row.width) / 2)
            case .trailing:
                xOffset = max(0, bounds.width - row.width)
            }

            var currentX = bounds.minX + xOffset
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: currentX, y: bounds.minY + row.originY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                currentX += item.size.width + spacing
            }
        }
    }

    private func makeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        guard !subviews.isEmpty else {
            return LayoutResult(size: .zero, rows: [])
        }

        let subviewSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let availableWidth = maxWidth.isFinite ? maxWidth : .infinity

        var rows: [Row] = []
        var currentItems: [Item] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        func finalizeRow() {
            guard !currentItems.isEmpty else { return }
            let row = Row(
                items: currentItems,
                width: currentWidth,
                height: currentHeight,
                originY: rows.reduce(0) { $0 + $1.height + rowSpacing }
            )
            rows.append(row)
            currentItems.removeAll(keepingCapacity: true)
            currentWidth = 0
            currentHeight = 0
        }

        for (index, size) in subviewSizes.enumerated() {
            let item = Item(index: index, size: size)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if !currentItems.isEmpty, availableWidth.isFinite, proposedWidth > availableWidth {
                finalizeRow()
            }

            if !currentItems.isEmpty {
                currentWidth += spacing
            }

            currentItems.append(item)
            currentWidth += size.width
            currentHeight = max(currentHeight, size.height)
        }

        finalizeRow()

        let totalHeight = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + max(0, CGFloat(rows.count - 1) * rowSpacing)

        let totalWidth = rows.map(\.width).max() ?? 0
        return LayoutResult(
            size: CGSize(
                width: proposal.width ?? totalWidth,
                height: totalHeight
            ),
            rows: rows
        )
    }

    private struct LayoutResult {
        let size: CGSize
        let rows: [Row]
    }

    private struct Row {
        let items: [Item]
        let width: CGFloat
        let height: CGFloat
        let originY: CGFloat
    }

    private struct Item {
        let index: Int
        let size: CGSize
    }
}
