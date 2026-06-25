import SwiftUI

/// Shared geometry constants for the Venn diagram. File-private so both
/// `VennOverlap` and `LobeLayout` read the same numbers.
private enum VennLayout {
    static let diagramHeight: CGFloat = 196
    static let maxRadius: CGFloat = 78
    static let minRadius: CGFloat = 38
}

/// The brand primitive: a true Venn diagram of how the viewer's taste
/// intersects the profile they're viewing.
///
/// The lens (the shared region) is drawn **explicitly** via `Canvas` —
/// clip to one lobe, fill the other in the brand accent — rather than the
/// old `.blendMode(.plusLighter)` trick, which rendered invisibly on a light
/// background. The result is identical in light and dark.
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
                    .foregroundStyle(Theme.Color.accentBlue)
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
            pairCanvas(yours: yours, theirs: theirs, shared: shared)
        }
    }

    private func soloCircle(_ set: Set) -> some View {
        Circle()
            .fill(Theme.Color.accentBlue)
            .frame(width: VennLayout.maxRadius * 2, height: VennLayout.maxRadius * 2)
            .overlay(
                Text(verbatim: "\(set.count)")
                    .font(Theme.Font.title.weight(.bold))
                    .foregroundStyle(Theme.Color.onAccent)
                    .monospacedDigit()
            )
            .frame(maxWidth: .infinity)
    }

    private func pairCanvas(yours: Set, theirs: Set, shared: Int) -> some View {
        // The lens is always horizontally + vertically centered, so the
        // shared chip can ride a plain centered overlay — no coordinate math,
        // and it stays legible however thin the lens gets.
        ZStack {
            Canvas { context, size in
                let layout = LobeLayout(
                    in: size,
                    viewer: yours.count,
                    other: theirs.count,
                    shared: shared
                )
                let viewerPath = Path(ellipseIn: layout.viewerRect)
                let otherPath = Path(ellipseIn: layout.otherRect)

                // Lobes: translucent fill + hairline stroke — legible in both
                // themes because graphite flips with the color scheme.
                context.fill(viewerPath, with: .color(Self.lobeFill))
                context.fill(otherPath, with: .color(Self.lobeFill))
                context.stroke(viewerPath, with: .color(Self.lobeStroke), lineWidth: 1.5)
                context.stroke(otherPath, with: .color(Self.lobeStroke), lineWidth: 1.5)

                // The lens: the intersection, filled with the brand accent.
                context.drawLayer { layer in
                    layer.clip(to: viewerPath)
                    layer.fill(otherPath, with: .color(Theme.Color.accentBlue))
                }

                // Unique counts sit out in each crescent.
                draw(yours.count - shared, at: layout.viewerLabelPoint, in: &context)
                draw(theirs.count - shared, at: layout.otherLabelPoint, in: &context)
            }

            if shared > 0 {
                sharedChip(shared)
            }
        }
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
            .background(Capsule().fill(Theme.Color.accentBlue))
            .overlay(Capsule().strokeBorder(Theme.Color.background, lineWidth: 2))
    }

    private func draw(_ value: Int, at point: CGPoint, in context: inout GraphicsContext) {
        var text = context.resolve(
            Text(verbatim: "\(value)").font(Theme.Font.headline).monospacedDigit()
        )
        text.shading = .color(Theme.Color.textPrimary)
        context.draw(text, at: point, anchor: .center)
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
                .fill(emphasised ? Theme.Color.accentBlue : Theme.Color.graphite.opacity(0.55))
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

/// Geometry for the two-lobe diagram, derived purely from the three counts
/// and the available canvas size. Lobe area tracks collection size (radius ∝
/// √count); the more the two share, the closer the centers sit.
private struct LobeLayout {
    let viewerRect: CGRect
    let otherRect: CGRect
    let viewerLabelPoint: CGPoint
    let otherLabelPoint: CGPoint
    let lensCenter: CGPoint

    init(in size: CGSize, viewer: Int, other: Int, shared: Int) {
        let maxCount = max(viewer, other, 1)
        let rViewer = LobeLayout.radius(for: viewer, maxCount: maxCount)
        let rOther = LobeLayout.radius(for: other, maxCount: maxCount)

        // More shared (relative to the union) → centers move closer.
        let union = max(viewer + other - shared, 1)
        let overlap = min(max(Double(shared) / Double(union), 0), 1)
        let maxDistance = Double(rViewer + rOther)
        let minDistance = Double(max(rViewer, rOther)) * 0.65
        let distance = CGFloat(maxDistance - (maxDistance - minDistance) * overlap)

        let mid = CGPoint(x: size.width / 2, y: size.height / 2)
        let viewerCenter = CGPoint(x: mid.x - distance / 2, y: mid.y)
        let otherCenter = CGPoint(x: mid.x + distance / 2, y: mid.y)

        viewerRect = LobeLayout.rect(center: viewerCenter, radius: rViewer)
        otherRect = LobeLayout.rect(center: otherCenter, radius: rOther)
        lensCenter = mid
        // Unique counts sit out in each crescent, away from the lens.
        viewerLabelPoint = CGPoint(x: viewerCenter.x - rViewer * 0.45, y: mid.y)
        otherLabelPoint = CGPoint(x: otherCenter.x + rOther * 0.45, y: mid.y)
    }

    private static func radius(for count: Int, maxCount: Int) -> CGFloat {
        let ratio = (Double(max(count, 0)) / Double(maxCount)).squareRoot()
        return VennLayout.minRadius
            + (VennLayout.maxRadius - VennLayout.minRadius) * CGFloat(ratio)
    }

    private static func rect(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
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
