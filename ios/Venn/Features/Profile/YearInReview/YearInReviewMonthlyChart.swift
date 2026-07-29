import SwiftUI

/// Trailing-12-month activity chart. Plain `Capsule` bars, not `Charts` or
/// `Canvas` — `VennOverlap` already hit the `Canvas`-renders-blank-in-
/// snapshots problem, so anything that needs a deterministic baseline on
/// CI stays built from ordinary `Shape`s.
struct YearInReviewMonthlyChart: View {
    let monthly: [MonthlyStat]

    private static let barHeight: CGFloat = 96
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private var maxCount: Int {
        monthly.map(\.count).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Activity")
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(alignment: .bottom, spacing: Theme.Spacing.xs) {
                ForEach(monthly, id: \.month) { point in
                    bar(for: point)
                }
            }
            .frame(height: Self.barHeight, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private func bar(for point: MonthlyStat) -> some View {
        let ratio = maxCount > 0 ? CGFloat(point.count) / CGFloat(maxCount) : 0
        return VStack(spacing: Theme.Spacing.xxs) {
            Capsule()
                .fill(ratio > 0 ? Theme.Color.accent : Theme.Color.surfaceStrong)
                .frame(height: max(Self.barHeight * ratio, 3))
            Text(Self.monthFormatter.string(from: point.month))
                .font(.caption2)
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var accessibilityLabel: Text {
        let summary = monthly
            .map { "\(Self.monthFormatter.string(from: $0.month)): \($0.count)" }
            .joined(separator: ", ")
        return Text(verbatim: "Monthly activity, trailing twelve months. \(summary).")
    }
}

#Preview {
    YearInReviewMonthlyChart(monthly: [
        .init(month: .init(timeIntervalSince1970: 0), count: 2),
        .init(month: .init(timeIntervalSince1970: 2_600_000), count: 5),
        .init(month: .init(timeIntervalSince1970: 5_200_000), count: 0),
        .init(month: .init(timeIntervalSince1970: 7_800_000), count: 9),
    ])
    .padding(Theme.Spacing.lg)
}
