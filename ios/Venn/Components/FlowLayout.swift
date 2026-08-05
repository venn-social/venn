import SwiftUI

/// Lays subviews out left to right, wrapping to a new line when the next
/// one won't fit — what CSS calls `flex-wrap`.
///
/// SwiftUI has no built-in equivalent: `HStack` never wraps and `LazyVGrid`
/// forces a column width, which is wrong for chips whose width is their
/// content (a "Drama" pill and a "Science Fiction" pill should not be the
/// same size). Used for genre chips and watch-provider chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = Theme.Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +)
            + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        var y = bounds.minY
        for row in rows(for: subviews, width: proposal.width ?? bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    /// One line's worth of subviews, plus the space it occupies.
    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width limit: CGFloat) -> [Row] {
        var rows = [Row()]

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty
                ? size.width
                : rows[rows.count - 1].width + spacing + size.width

            // A subview wider than the whole container still gets its own
            // row rather than an empty one above it.
            if needed > limit, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }

            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += isFirst ? size.width : spacing + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }

        return rows
    }
}

#Preview {
    FlowLayout {
        ForEach(["Drama", "Romance", "Science Fiction", "Documentary", "Thriller"], id: \.self) {
            Text($0)
                .font(Theme.Font.footnote)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Color.surfaceStrong, in: .capsule)
        }
    }
    .padding(Theme.Spacing.lg)
}
