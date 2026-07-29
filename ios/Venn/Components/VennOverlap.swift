import SwiftUI

/// Shared geometry constants for the Venn diagram. File-private so both
/// `VennOverlap` and `PairGeometry` read the same numbers.
private enum VennLayout {
    static let diagramHeight: CGFloat = 180
    static let maxRadius: CGFloat = 78
    static let minRadius: CGFloat = 38
}

/// The brand primitive: a true Venn diagram of how the viewer's taste
/// intersects the profile they're viewing.
///
/// Built from plain SwiftUI shapes (two `Circle` lobes; the lens is a blue
/// circle `.mask`ed to the other lobe) — deliberately **not** `Canvas`, which
/// renders blank through the snapshot-test layer path. No blend modes, so it
/// looks identical in light and dark, and the same in the app, in
/// `ImageRenderer`, and in snapshot baselines.
///
/// Two modes:
/// - `.solo` — a single accent circle with a count. Used on your own profile,
///   where there's nothing to compare against.
/// - `.pair` — two lobes whose **area tracks each collection's size** and
///   which sit closer together the more the two people share. A "NN% match"
///   (Jaccard) headline sits above, and a three-row legend below.
///
/// Both modes share the same outer footprint so layout doesn't jump when
/// navigating between profiles.
struct VennOverlap: View {
    enum Mode: Equatable {
        case solo(Set)
        case pair(yours: Set, theirs: Set, shared: Int)
    }

    /// One side of the diagram. `count` is the total size of that person's
    /// collection; unique-vs-shared math happens at render time.
    struct Set: Equatable {
        let label: LocalizedStringKey
        let count: Int
    }

    let mode: Mode

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            header
            diagram
                .frame(height: VennLayout.diagramHeight)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
            legend
        }
    }

    // MARK: - Header (match %)

    @ViewBuilder private var header: some View {
        if case let .pair(yours, theirs, shared) = mode {
            matchHeader(yours: yours, theirs: theirs, shared: shared)
        }
    }

    @ViewBuilder
    private func matchHeader(yours: Set, theirs: Set, shared: Int) -> some View {
        if let percent = TasteMatch.percent(shared: shared, viewer: yours.count, other: theirs.count) {
            VStack(spacing: Theme.Spacing.xxs) {
                Text(verbatim: "\(percent)%")
                    .font(Theme.Font.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.Color.accent)
                    .monospacedDigit()
                Text("taste match")
                    .font(Theme.Font.caption.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
    }

    // MARK: - Diagram

    @ViewBuilder private var diagram: some View {
        switch mode {
        case let .solo(only):
            soloCircle(only)
        case let .pair(yours, theirs, shared):
            pairDiagram(yours: yours, theirs: theirs, shared: shared)
        }
    }

    private func soloCircle(_ set: Set) -> some View {
        Circle()
            .fill(Theme.Color.accent)
            .frame(width: VennLayout.maxRadius * 2, height: VennLayout.maxRadius * 2)
            .overlay(
                Text(verbatim: "\(set.count)")
                    .font(Theme.Font.title.weight(.bold))
                    .foregroundStyle(Theme.Color.onAccent)
                    .monospacedDigit()
            )
    }

    private func pairDiagram(yours: Set, theirs: Set, shared: Int) -> some View {
        let geometry = PairGeometry(viewer: yours.count, other: theirs.count, shared: shared)
        return GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2
            let viewerX = centerX - geometry.halfDistance
            let otherX = centerX + geometry.halfDistance

            ZStack {
                lobe(diameter: geometry.viewerDiameter).position(x: viewerX, y: centerY)
                lobe(diameter: geometry.otherDiameter).position(x: otherX, y: centerY)

                // The lens: the brand-accent other-lobe, masked to the viewer
                // lobe, so only the intersection shows.
                Circle()
                    .fill(Theme.Color.accent)
                    .frame(width: geometry.otherDiameter, height: geometry.otherDiameter)
                    .position(x: otherX, y: centerY)
                    .mask(
                        Circle()
                            .frame(width: geometry.viewerDiameter, height: geometry.viewerDiameter)
                            .position(x: viewerX, y: centerY)
                    )

                // Unique counts sit out in each crescent.
                countText(yours.count - shared)
                    .position(x: viewerX - geometry.viewerRadius * 0.45, y: centerY)
                countText(theirs.count - shared)
                    .position(x: otherX + geometry.otherRadius * 0.45, y: centerY)

                if shared > 0 {
                    sharedChip(shared).position(x: centerX, y: centerY)
                }
            }
        }
    }

    private func lobe(diameter: CGFloat) -> some View {
        Circle()
            .fill(Self.lobeFill)
            .overlay(Circle().strokeBorder(Self.lobeStroke, lineWidth: 1.5))
            .frame(width: diameter, height: diameter)
    }

    private func countText(_ value: Int) -> some View {
        Text(verbatim: "\(value)")
            .font(Theme.Font.headline)
            .monospacedDigit()
            .foregroundStyle(Theme.Color.textPrimary)
    }

    /// The shared count, as a brand-blue chip pinned over the lens. A chip
    /// (rather than raw text in the lens) keeps the number readable even when
    /// a low match makes the lens a thin sliver.
    private func sharedChip(_ shared: Int) -> some View {
        Text(verbatim: "\(shared)")
            .font(Theme.Font.title3.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(Theme.Color.onAccent)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(Capsule().fill(Theme.Color.accent))
            .overlay(Capsule().strokeBorder(Theme.Color.background, lineWidth: 2))
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
                legendRow(label: "in common", count: shared, emphasised: true)
                legendRow(label: theirs.label, count: theirs.count - shared)
            }
        }
    }

    private func legendRow(
        label: LocalizedStringKey,
        count: Int,
        emphasised: Bool = false
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(emphasised ? Theme.Color.accent : Theme.Color.graphite.opacity(0.55))
                .frame(width: 8, height: 8)
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

    // MARK: - Accessibility

    private var accessibilityLabel: Text {
        switch mode {
        case let .solo(only):
            return Text(only.label)
        case let .pair(yours, theirs, shared):
            let percent = TasteMatch.percent(
                shared: shared, viewer: yours.count, other: theirs.count
            ) ?? 0
            let summary = "\(percent)% taste match. "
                + "\(shared) in common, "
                + "\(yours.count - shared) only you, "
                + "\(theirs.count - shared) only them."
            return Text(verbatim: summary)
        }
    }

    // MARK: - Lobe colors

    private static let lobeFill = Theme.Color.graphite.opacity(0.08)
    private static let lobeStroke = Theme.Color.graphite.opacity(0.45)
}

/// Geometry for the two-lobe diagram, derived purely from the three counts.
/// Lobe area tracks collection size (radius ∝ √count); the more the two
/// share, the closer the centers sit.
private struct PairGeometry {
    let viewerRadius: CGFloat
    let otherRadius: CGFloat
    let halfDistance: CGFloat

    init(viewer: Int, other: Int, shared: Int) {
        let maxCount = max(viewer, other, 1)
        viewerRadius = PairGeometry.radius(for: viewer, maxCount: maxCount)
        otherRadius = PairGeometry.radius(for: other, maxCount: maxCount)

        // More shared (relative to the union) → centers move closer.
        let union = max(viewer + other - shared, 1)
        let overlap = min(max(Double(shared) / Double(union), 0), 1)
        let maxDistance = Double(viewerRadius + otherRadius)
        let minDistance = Double(max(viewerRadius, otherRadius)) * 0.65
        halfDistance = CGFloat(maxDistance - (maxDistance - minDistance) * overlap) / 2
    }

    var viewerDiameter: CGFloat {
        viewerRadius * 2
    }

    var otherDiameter: CGFloat {
        otherRadius * 2
    }

    private static func radius(for count: Int, maxCount: Int) -> CGFloat {
        let ratio = (Double(max(count, 0)) / Double(maxCount)).squareRoot()
        return VennLayout.minRadius
            + (VennLayout.maxRadius - VennLayout.minRadius) * CGFloat(ratio)
    }
}

#Preview("pair – light") {
    VennOverlap(mode: .pair(
        yours: .init(label: "Only you", count: 47),
        theirs: .init(label: "Only Vivian", count: 32),
        shared: 12
    ))
    .padding(Theme.Spacing.xl)
}

#Preview("pair – dark") {
    VennOverlap(mode: .pair(
        yours: .init(label: "Only you", count: 47),
        theirs: .init(label: "Only Vivian", count: 32),
        shared: 12
    ))
    .padding(Theme.Spacing.xl)
    .preferredColorScheme(.dark)
}

#Preview("pair – lopsided") {
    VennOverlap(mode: .pair(
        yours: .init(label: "Only you", count: 8),
        theirs: .init(label: "Only Sam", count: 120),
        shared: 5
    ))
    .padding(Theme.Spacing.xl)
}

#Preview("pair – no shared") {
    VennOverlap(mode: .pair(
        yours: .init(label: "Only you", count: 20),
        theirs: .init(label: "Only Sam", count: 15),
        shared: 0
    ))
    .padding(Theme.Spacing.xl)
}

#Preview("solo") {
    VennOverlap(mode: .solo(.init(label: "Things you've logged", count: 47)))
        .padding(Theme.Spacing.xl)
}
