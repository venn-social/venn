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
/// **Determinism**: every assertion goes through `assertComponent` which
/// pins the color scheme to `.light` and uses a fixed-size frame. Without
/// the color-scheme pin, our newly-adaptive Theme colors (e.g.
/// `Theme.Color.onAccent`) render differently depending on the host
/// simulator's default appearance, which differs between local Macs and
/// the GitHub Actions runner.
///
/// `perceptualPrecision: 0.92` is the documented floor (see the saved
/// memory `feedback_snapshot_precision`). It tolerates SF-Symbol hinting
/// drift between machines while still flagging real visual diffs.
@MainActor
@Suite(.snapshots(record: .missing, diffTool: .ksdiff))
struct ComponentSnapshotTests {
    // MARK: - PrimaryButton

    @Test
    func primaryButton_idle() {
        assertComponent(
            PrimaryButton(title: "Continue") {},
            width: 360,
            height: 96
        )
    }

    @Test
    func primaryButton_loading() {
        assertComponent(
            PrimaryButton(title: "Continue", isLoading: true) {},
            width: 360,
            height: 96
        )
    }

    @Test
    func primaryButton_disabled() {
        assertComponent(
            PrimaryButton(title: "Continue", isEnabled: false) {},
            width: 360,
            height: 96
        )
    }

    // MARK: - SecondaryButton

    @Test
    func secondaryButton_idle() {
        assertComponent(
            SecondaryButton(title: "Sign out") {},
            width: 360,
            height: 96
        )
    }

    @Test
    func secondaryButton_disabled() {
        assertComponent(
            SecondaryButton(title: "Sign out", isEnabled: false) {},
            width: 360,
            height: 96
        )
    }

    // MARK: - EmptyStateView

    @Test
    func emptyState_noAction() {
        assertComponent(
            EmptyStateView(
                systemImage: "tray",
                title: "Nothing here yet",
                message: "Posts from people you follow will appear here."
            ),
            width: 390,
            height: 500
        )
    }

    @Test
    func emptyState_withAction() {
        assertComponent(
            EmptyStateView(
                systemImage: "person.2",
                title: "No friends yet",
                message: "Find friends to see where your tastes overlap.",
                actionTitle: "Find friends"
            ) {},
            width: 390,
            height: 560
        )
    }

    // MARK: - VennOverlap (the brand primitive)

    @Test
    func vennOverlap_solo() {
        assertComponent(
            VennOverlap(mode: .solo(.init(
                label: "Things you've logged",
                count: 47
            ))),
            width: 390,
            height: 360
        )
    }

    @Test
    func vennOverlap_pair() {
        assertComponent(
            VennOverlap(mode: .pair(
                yours: .init(label: "Only you", count: 47),
                theirs: .init(label: "Only Vivian", count: 32),
                shared: 12
            )),
            width: 390,
            height: 360
        )
    }

    // MARK: - helpers

    /// Centralises the test fixture so every assertion shares the same
    /// color scheme, padding shape, background, and precision threshold.
    ///
    /// `testName` defaults to `#function` of the caller (which is the
    /// `@Test` method's name), so each test gets its own snapshot file.
    /// Without this, every test would collide on `assertComponent.png`.
    private func assertComponent<V: View>(
        _ view: V,
        width: CGFloat,
        height: CGFloat,
        testName: String = #function,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let composed = view
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.background)
            .environment(\.colorScheme, .light)

        assertSnapshot(
            of: composed,
            as: .image(
                precision: 0.97,
                perceptualPrecision: 0.92,
                layout: .fixed(width: width, height: height)
            ),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
