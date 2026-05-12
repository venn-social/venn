import SwiftUI

/// The brand primitive. Renders one or two overlapping circles to visualize
/// how many items the viewer and the profile they're viewing share.
///
/// Two modes:
///
/// - `.solo` — one accent-colored circle with a single label + count. Used
///   on your own profile, where there's nothing to compare against.
/// - `.pair` — two soft circles overlapping; the lens region between them
///   is a deeper accent. Used on someone else's profile to show "X items
///   only you have", "Y items only they have", "Z items shared".
///
/// Both modes share the same outer footprint so the layout doesn't jump
/// when navigating between profiles.
struct VennOverlap: View {
    enum Mode: Equatable {
        case solo(Set)
        case pair(yours: Set, theirs: Set, shared: Int)
    }

    /// One side of the diagram. Used as the singleton in `.solo` and as
    /// each lobe in `.pair`. `count` is the total size of that person's
    /// collection (NOT the unique-to-them count — the math is done at
    /// render time so callers can supply totals from the database).
    struct Set: Equatable {
        let label: LocalizedStringKey
        let count: Int
    }

    let mode: Mode

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            diagram
                .frame(height: diagramHeight)
            legend
        }
    }

    // MARK: - Diagram

    private var diagramHeight: CGFloat {
        180
    }

    private var circleSize: CGFloat {
        140
    }

    /// How far each lobe sits from the centerline. The smaller this number,
    /// the larger the overlap. ~30% of the radius gives a recognisably
    /// "venn" lens without crowding the labels inside.
    private var lobeOffset: CGFloat {
        circleSize * 0.32
    }

    @ViewBuilder private var diagram: some View {
        switch mode {
        case let .solo(only):
            soloCircle(only)
        case let .pair(yours, theirs, _):
            pairCircles(yours: yours, theirs: theirs)
        }
    }

    private func soloCircle(_ set: Set) -> some View {
        Circle()
            .fill(Theme.Gradient.overlap)
            .frame(width: circleSize, height: circleSize)
            .overlay(
                Text(verbatim: "\(set.count)")
                    .font(Theme.Font.title.weight(.bold))
                    .foregroundStyle(.white)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(set.label)
            .accessibilityValue(Text(verbatim: "\(set.count)"))
    }

    private func pairCircles(yours: Set, theirs: Set) -> some View {
        ZStack {
            // The two soft lobes. .blendMode(.plusLighter) makes the lens
            // region intensify the accent color where they overlap.
            Circle()
                .fill(Theme.Color.graphite.opacity(0.72))
                .frame(width: circleSize, height: circleSize)
                .offset(x: -lobeOffset)
                .blendMode(.plusLighter)

            Circle()
                .fill(Theme.Color.graphite.opacity(0.34))
                .frame(width: circleSize, height: circleSize)
                .offset(x: lobeOffset)
                .blendMode(.plusLighter)

            // Counts sit at the visual center of each region.
            HStack(spacing: 0) {
                lobeLabel(count: yours.count)
                    .offset(x: -lobeOffset - circleSize / 4)
                Spacer().frame(width: 0)
                lobeLabel(count: theirs.count)
                    .offset(x: lobeOffset + circleSize / 4)
            }
        }
        .compositingGroup()
        .accessibilityElement(children: .combine)
    }

    private func lobeLabel(count: Int) -> some View {
        Text(verbatim: "\(count)")
            .font(Theme.Font.title2.weight(.bold))
            .foregroundStyle(.white)
    }

    // MARK: - Legend

    @ViewBuilder private var legend: some View {
        switch mode {
        case let .solo(only):
            Text(only.label)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
        case let .pair(yours, theirs, shared):
            VStack(spacing: Theme.Spacing.xs) {
                legendRow(label: yours.label, count: yours.count - shared)
                legendRow(label: "in common", count: shared)
                legendRow(label: theirs.label, count: theirs.count - shared)
            }
        }
    }

    private func legendRow(
        label: LocalizedStringKey,
        count: Int,
        emphasised: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(emphasised ? Theme.Font.body.weight(.semibold) : Theme.Font.body)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
            Text(verbatim: "\(count)")
                .font(emphasised ? Theme.Font.body.weight(.semibold) : Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .monospacedDigit()
        }
    }
}

#Preview("solo") {
    VennOverlap(mode: .solo(.init(label: "Things you've logged", count: 47)))
        .padding(Theme.Spacing.xl)
}

#Preview("pair") {
    VennOverlap(mode: .pair(
        yours: .init(label: "Only you", count: 47),
        theirs: .init(label: "Only Vivian", count: 32),
        shared: 12
    ))
    .padding(Theme.Spacing.xl)
}
