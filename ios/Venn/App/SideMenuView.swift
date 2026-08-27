import SwiftUI

/// The secondary surfaces, reachable from one control.
///
/// Feed, Explorer and Profile are where the product lives; Lists,
/// Activity, Last 12 Months and Settings are places you go on purpose.
/// Keeping all seven at top level made none of them read as primary, so
/// these four moved behind a trailing-edge panel — and live nowhere else,
/// so there is exactly one way to each.
///
/// Mirrors web's `SideMenu.tsx`: same four destinations, same order, same
/// labels.
enum SideMenuDestination: String, CaseIterable, Identifiable {
    case settings
    case lists
    case activity
    case yearInReview

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .lists: "Lists"
        case .activity: "Activity"
        case .yearInReview: "Last 12 Months"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .lists: "list.bullet"
        case .activity: "bell"
        // Rewind, not a bar chart: the screen is the year played back,
        // and a chart promised statistics it does not show. Matches web.
        case .yearInReview: "backward.fill"
        case .settings: "gearshape"
        }
    }
}

struct SideMenuView: View {
    @Binding var isPresented: Bool
    let unreadCount: Int
    var onSelect: (SideMenuDestination) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            // Tap-away. Above the app, below the panel.
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityLabel("Close menu")
                .accessibilityAddTraits(.isButton)

            panel
                .transition(.move(edge: .leading))
        }
        // `.contain`, explicitly. Attaching an accessibility modifier to a
        // container lets SwiftUI merge the subtree into one element, which
        // is what hid every row here: the panel rendered and was tappable
        // by sight, but none of its buttons existed to VoiceOver or to a
        // UI test. The dimmer below being its own labelled element made the
        // merge more likely, not less.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("side_menu")
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(SideMenuDestination.allCases) { destination in
                Button {
                    close()
                    onSelect(destination)
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: destination.systemImage)
                            .frame(width: 22)
                        Text(destination.title)
                            .font(Theme.Font.body)
                        Spacer(minLength: 0)
                        if destination == .activity, unreadCount > 0 {
                            Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                                .font(Theme.Font.caption.weight(.semibold))
                                .foregroundStyle(Theme.Color.onAccent)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Theme.Color.accent, in: .capsule)
                        }
                    }
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.horizontal, Theme.Spacing.md)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("side_menu_\(destination.rawValue)")
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Spacing.xxl)
        .frame(width: 240)
        .frame(maxHeight: .infinity)
        .background(Theme.Color.background)
        .ignoresSafeArea()
    }

    private func close() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isPresented = false
        }
    }
}

#Preview("Light") {
    @Previewable @State var shown = true
    return SideMenuView(isPresented: $shown, unreadCount: 3) { _ in }
}

#Preview("Dark") {
    @Previewable @State var shown = true
    return SideMenuView(isPresented: $shown, unreadCount: 0) { _ in }
        .preferredColorScheme(.dark)
}
