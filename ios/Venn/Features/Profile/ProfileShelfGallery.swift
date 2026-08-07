import SwiftUI

/// Three-column cover grid for one profile shelf, with the shelf's
/// empty-state copy. Shared by the signed-in `ProfileView` and the
/// read-only `PublicProfileView`.
///
/// Tapping a cover opens that title's detail screen, the same as on web.
/// Both hosts must therefore register `.navigationDestination(for:
/// Media.self)` — the grid pushes a value, not a view, so it holds no
/// opinion about what the destination looks like.
///
/// On your own shelf it also carries the editing affordances: a long-press
/// menu with Edit and Remove, and drag-to-reorder. Both are off for other
/// people's shelves, where there is nothing to edit.
struct ProfileShelfGallery: View {
    let items: [LibraryItem]
    let emptyMessage: LocalizedStringKey

    /// Your own shelf. Enables the context menu and dragging.
    var canEdit = false
    var onEdit: ((LibraryItem) -> Void)?
    var onRemove: ((LibraryItem) -> Void)?
    /// Called with the settled order after a drop.
    var onReorder: (([UUID]) -> Void)?

    /// Live order while a drag is in flight. Nil means "use `items`", so a
    /// reload is never fighting a stale local copy.
    @State private var dragOrder: [UUID]?
    @State private var dragging: LibraryItem?

    private var ordered: [LibraryItem] {
        guard let dragOrder else { return items }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return dragOrder.compactMap { byID[$0] }
    }

    var body: some View {
        if items.isEmpty {
            Text(emptyMessage)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.Spacing.md)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3),
                spacing: Theme.Spacing.sm
            ) {
                ForEach(ordered) { item in
                    NavigationLink(value: item.media) {
                        cover(for: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: item) }
                    .modifier(ReorderModifier(
                        enabled: canEdit,
                        item: item,
                        ordered: ordered,
                        dragging: $dragging,
                        dragOrder: $dragOrder,
                        onReorder: onReorder
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private func menu(for item: LibraryItem) -> some View {
        if canEdit {
            Button("Edit", systemImage: "pencil") { onEdit?(item) }
            Button("Remove", systemImage: "trash", role: .destructive) { onRemove?(item) }
        }
    }

    private func cover(for item: LibraryItem) -> some View {
        MediaCoverTile(
            title: item.media.title,
            kind: item.media.kind,
            coverURL: item.media.coverURL,
            height: 150,
            cornerRadius: Theme.Radius.md
        )
    }
}

/// Drag-to-reorder, kept out of the grid body so the view stays readable.
///
/// `onMove`-style reordering needs a `List`; this is a `LazyVGrid`, so the
/// grid uses `draggable` + `dropDestination` and rearranges as the finger
/// passes over each cell. Committing happens on drop rather than on every
/// crossing, so one gesture is one write.
private struct ReorderModifier: ViewModifier {
    let enabled: Bool
    let item: LibraryItem
    let ordered: [LibraryItem]
    @Binding var dragging: LibraryItem?
    @Binding var dragOrder: [UUID]?
    let onReorder: (([UUID]) -> Void)?

    func body(content: Content) -> some View {
        if enabled {
            content
                .opacity(dragging?.id == item.id ? 0.5 : 1)
                .draggable(item.media.title) {
                    // The preview doubles as the signal that the long-press
                    // became a drag rather than opening the menu.
                    Text(item.media.title)
                        .font(Theme.Font.caption)
                        .padding(Theme.Spacing.xs)
                        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
                        .onAppear { dragging = item }
                }
                .dropDestination(for: String.self) { _, _ in
                    commit()
                    return true
                } isTargeted: { targeted in
                    if targeted {
                        rearrange()
                    }
                }
        } else {
            content
        }
    }

    /// Move the dragged item to this cell's slot, live.
    private func rearrange() {
        guard let dragging, dragging.id != item.id else { return }

        var order = dragOrder ?? ordered.map(\.id)
        guard let from = order.firstIndex(of: dragging.id),
              let to = order.firstIndex(of: item.id)
        else {
            return
        }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        dragOrder = order
    }

    private func commit() {
        if let dragOrder {
            onReorder?(dragOrder)
        }
        dragging = nil
        // Held until the reload lands, so the covers do not snap back to the
        // old order for a frame before the new one arrives.
    }
}

#Preview("Own shelf") {
    NavigationStack {
        ProfileShelfGallery(
            items: [],
            emptyMessage: "Nothing in your collection yet.",
            canEdit: true
        )
        .padding(Theme.Spacing.lg)
    }
}
