import SwiftUI

/// Profile-owned appearance controls. Keeping this as a small section avoids
/// letting settings logic leak into the profile screen layout.
struct ProfileAppearanceSection: View {
    @Environment(AppearanceSettings.self)
    private var appearanceSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Appearance")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)

            GlassSegmentedControl(
                items: AppThemeMode.allCases,
                selection: selection,
                title: \.title,
                systemImage: \.systemImage
            )
            .accessibilityIdentifier("appearance_theme_picker")
        }
        .sensoryFeedback(.selection, trigger: appearanceSettings.mode)
    }

    private var selection: Binding<AppThemeMode> {
        Binding {
            appearanceSettings.mode
        } set: { mode in
            appearanceSettings.mode = mode
        }
    }
}

#Preview {
    Screen {
        ProfileAppearanceSection()
    }
    .environment(AppearanceSettings())
}
