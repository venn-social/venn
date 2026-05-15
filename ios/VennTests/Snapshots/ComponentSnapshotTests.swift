import SnapshotTesting
import SwiftUI
import Testing
@testable import Venn

/// Snapshot baselines for the design-system primitives.
///
/// **Source of truth = CI.** Snapshots that drift between local Macs and
/// the GitHub Actions runner are routine for views that involve
/// gradients, blend modes, or animations (PrimaryButton's capsule fill,
/// VennOverlap's `.plusLighter` lobes). Trying to find a single
/// precision threshold that satisfied both environments was a losing
/// game (PR #68 burned 4 CI cycles on this). The record-on-CI workflow
/// instead pins the baseline to what CI actually renders.
///
/// **Workflow when a snapshot fails:**
/// 1. CI uploads the newly-rendered images as an artifact named
///    `snapshot-baselines-<sha>` — see `.github/workflows/ci.yml`.
/// 2. Download the artifact: `gh run download <run-id> -n
///    snapshot-baselines-<sha>`.
/// 3. Inspect the new PNGs visually. If they reflect intentional
///    visual changes, copy them into
///    `ios/VennTests/Snapshots/__Snapshots__/ComponentSnapshotTests/`.
/// 4. Commit + push. CI re-runs and the new baselines match.
///
/// `record: .failed` makes the framework auto-write a snapshot whenever
/// comparison fails, so step 1 happens automatically.
///
/// **Determinism**: every assertion goes through `assertComponent` which
/// pins the color scheme to `.light` and uses a fixed-size frame.
/// Without the color-scheme pin, adaptive Theme colors render
/// differently depending on the simulator's default appearance.
///
/// **Precision**: `precision: 0.95, perceptualPrecision: 0.80`. Once
/// baselines come from CI itself, this tolerance is effectively just
/// belt-and-suspenders against any leftover noise.
@MainActor
@Suite(.snapshots(record: .failed, diffTool: .ksdiff))
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
                precision: 0.95,
                perceptualPrecision: 0.80,
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
