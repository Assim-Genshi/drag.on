import SwiftUI

/// A grid cell view representing a single file item inside the Lair Manager.
struct FileGridCell: View {
    let item: FileItem
    let store: LairStore
    let isSelected: Bool
    let onSelectToggle: () -> Void
    let getSelectedItems: () -> [FileItem]

    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    init(
        item: FileItem,
        store: LairStore,
        isSelected: Bool,
        onSelectToggle: @escaping () -> Void,
        getSelectedItems: @escaping () -> [FileItem]
    ) {
        self.item = item
        self.store = store
        self.isSelected = isSelected
        self.onSelectToggle = onSelectToggle
        self.getSelectedItems = getSelectedItems
        
        let cached = ThumbnailCache.shared.cachedImage(for: item.filePath)
        self._thumbnail = State(initialValue: cached)
    }

    private var content100: Color {
        Color("content-100")
    }

    private var content200: Color {
        Color("content-200")
    }

    private var borderColor: Color {
        Color("border-color")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                ZStack {
                    if let img = thumbnail {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    } else {
                        Image(nsImage: item.placeholderImage())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                    }
                }
                .frame(width: 54, height: 54)

                Text(item.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(content100)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.24) : Color.clear, lineWidth: 1.0)
            )

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.blue : content200.opacity(0.4))
                        .padding(6)
                }
                Spacer()
            }

            DragSourceHelper(
                item: item,
                store: store,
                isSelected: isSelected,
                onSelectToggle: onSelectToggle,
                onHoverToggle: { hover in
                    self.isHovered = hover
                },
                getSelectedItems: getSelectedItems
            )
        }
        .frame(height: 94)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        Task { @MainActor in
            let img = await item.thumbnailAsync()
            self.thumbnail = img
        }
    }
}
