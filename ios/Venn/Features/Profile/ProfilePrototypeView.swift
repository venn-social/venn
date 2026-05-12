import SwiftUI

#if DEBUG
    struct ProfilePrototypeView: View {
        var body: some View {
            NavigationStack {
                Screen {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                            ProfileHeaderView(
                                name: "Maya Chen",
                                handle: "maya",
                                bio: "movies that linger, loud dinners, albums with one perfect skip"
                            )

                            HStack(spacing: Theme.Spacing.sm) {
                                MetricTile(value: "128", label: "watched")
                                MetricTile(value: "34", label: "saved")
                                MetricTile(value: "18", label: "overlaps")
                            }

                            ProfileLibrarySection(categories: ProfileLibraryCategory.prototype)
                        }
                        .padding(.vertical, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xxxl * 2)
                    }
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    #Preview {
        ProfilePrototypeView()
    }
#endif
