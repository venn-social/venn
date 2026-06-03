#if DEBUG
    import SwiftUI

    /// Explore page for the visual style preview: category filters above a
    /// two-column masonry of catalog entries. DEBUG-only.
    struct ExplorePreviewPage: View {
        @Environment(\.colorScheme)
        private var scheme
        @State private var category: Category = .all

        private enum Category: String, CaseIterable, Identifiable {
            case all = "All", movies = "Movies", music = "Music", books = "Books"
            var id: Self {
                self
            }
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        categoryFilter
                        masonry
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
                .stylePreviewSurface()
            }
        }

        private var categoryFilter: some View {
            HStack(spacing: 8) {
                ForEach(Category.allCases) { item in
                    let selected = item == category
                    Text(item.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selected ? Color.white : StyleToken.inkSecondary(scheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selected ? StyleToken.ink(scheme) : StyleToken.hairline(scheme),
                            in: .capsule
                        )
                        .onTapGesture { category = item }
                }
            }
        }

        private var masonry: some View {
            let entries = StyleSampleData.catalog
            let leading = entries.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element)
            let trailing = entries.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element)
            return HStack(alignment: .top, spacing: 12) {
                masonryColumn(leading)
                masonryColumn(trailing)
            }
        }

        private func masonryColumn(_ entries: [StyleEntry]) -> some View {
            VStack(spacing: 18) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        StyleCoverTile(title: entry.title, kind: entry.kind, height: entry.tileHeight)
                        Text(entry.title)
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(StyleToken.ink(scheme))
                            .lineLimit(2)
                        Text(entry.creator)
                            .font(.system(size: 13))
                            .foregroundStyle(StyleToken.inkSecondary(scheme))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    #Preview("light") {
        ZStack { GlassSkyBackground()
            ExplorePreviewPage()
        }
        .environment(AppearanceSettings())
        .preferredColorScheme(.light)
    }

    #Preview("dark") {
        ZStack { GlassSkyBackground()
            ExplorePreviewPage()
        }
        .environment(AppearanceSettings())
        .preferredColorScheme(.dark)
    }
#endif
