import SnapshotTesting
import SwiftUI
import Testing
@testable import Venn

/// Snapshot baselines for the design-system primitives.
///
/// Snapshots are recorded on first run (a missing snapshot fails the test
/// once and creates the file); every run after compares pixel-for-pixel.
/// Commit the recorded `__Snapshots__/` files alongside the test file —
/// they ARE the regression baseline.
///
/// Layout strategy: every assertion uses `.image(layout: .fixed(...))`
/// instead of `.device(...)`. Fixed-size frames are deterministic across
/// host machines; full-device renders aren't because of safe-area insets,
/// status-bar variations, and dynamic-type defaults.
///
/// `perceptualPrecision: 0.95` lets sub-pixel font-rendering noise pass
/// while still flagging real visual diffs. Tighten if tests start
/// missing real regressions.
@MainActor
@Suite(.snapshots(record: .missing, diffTool: .ksdiff))
struct ComponentSnapshotTests {
    // MARK: - PrimaryButton

    @Test
    func primaryButton_idle() {
        let view = PrimaryButton(title: "Continue") {}
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 360, height: 96)
        ))
    }

    @Test
    func primaryButton_loading() {
        let view = PrimaryButton(title: "Continue", isLoading: true) {}
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 360, height: 96)
        ))
    }

    @Test
    func primaryButton_disabled() {
        let view = PrimaryButton(title: "Continue", isEnabled: false) {}
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 360, height: 96)
        ))
    }

    // MARK: - SecondaryButton

    @Test
    func secondaryButton_idle() {
        let view = SecondaryButton(title: "Sign out") {}
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 360, height: 96)
        ))
    }

    @Test
    func secondaryButton_disabled() {
        let view = SecondaryButton(title: "Sign out", isEnabled: false) {}
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 360, height: 96)
        ))
    }

    // MARK: - EmptyStateView

    @Test
    func emptyState_noAction() {
        let view = EmptyStateView(
            systemImage: "tray",
            title: "Nothing here yet",
            message: "Posts from people you follow will appear here."
        )
        .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 390, height: 500)
        ))
    }

    @Test
    func emptyState_withAction() {
        let view = EmptyStateView(
            systemImage: "person.2",
            title: "No friends yet",
            message: "Find friends to see where your tastes overlap.",
            actionTitle: "Find friends"
        ) {}
            .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 390, height: 560)
        ))
    }

    // MARK: - VennOverlap (the brand primitive)

    @Test
    func vennOverlap_solo() {
        let view = VennOverlap(mode: .solo(.init(
            label: "Things you've logged",
            count: 47
        )))
        .padding(Theme.Spacing.lg)
        .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 390, height: 360)
        ))
    }

    @Test
    func vennOverlap_pair() {
        let view = VennOverlap(mode: .pair(
            yours: .init(label: "Only you", count: 47),
            theirs: .init(label: "Only Vivian", count: 32),
            shared: 12
        ))
        .padding(Theme.Spacing.lg)
        .background(Theme.Color.background)

        assertSnapshot(of: view, as: .image(
            perceptualPrecision: 0.95,
            layout: .fixed(width: 390, height: 360)
        ))
    }
}
