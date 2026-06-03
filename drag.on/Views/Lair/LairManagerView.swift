import SwiftUI

/// A panel view that displays the grid of items currently inside the Lair
/// and provides batch management operations (Open, Reveal, Convert, Delete).
struct LairManagerView: View {
    var store: LairStore
    var uiState: LairUIState
    var onClose: () -> Void
    var onConvertSelected: ([FileItem]) -> Void

    private var content100: Color {
        Color("content-100")
    }

    private var content200: Color {
        Color("content-200")
    }

    private var selectedItems: [FileItem] {
        store.items.filter { uiState.selectedItemIDs.contains($0.id) }
    }

    private var selectedImages: [FileItem] {
        selectedItems.filter(\.isImage)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                LairCircleButton(systemName: "chevron.left", action: {
                    withAnimation(.snappy(duration: 0.3)) {
                        uiState.isManagementPanelActive = false
                    }
                })
                .pointerCursor()
                
                Spacer()
                
                Text(uiState.selectedItemIDs.isEmpty ? "Lair Manager" : "\(uiState.selectedItemIDs.count) Selected")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(content100)
                
                Spacer()
                
                LairCircleButton(systemName: "xmark", action: {
                    store.clearAll()
                    onClose()
                })
                .pointerCursor()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Scrollable Grid of file items
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 95, maximum: 110), spacing: 10)
                ], spacing: 10) {
                    ForEach(store.items) { item in
                        FileGridCell(
                            item: item,
                            store: store,
                            isSelected: uiState.selectedItemIDs.contains(item.id),
                            onSelectToggle: {
                                withAnimation(.snappy(duration: 0.25)) {
                                    if uiState.selectedItemIDs.contains(item.id) {
                                        uiState.selectedItemIDs.remove(item.id)
                                    } else {
                                        uiState.selectedItemIDs.insert(item.id)
                                    }
                                }
                            },
                            getSelectedItems: {
                                selectedItems
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            
            Spacer(minLength: 8)
            
            // Floating management action bar
            managementActionBar
                .padding(.bottom, 14)
        }
    }

    private var managementActionBar: some View {
        ZStack {
            if uiState.selectedItemIDs.isEmpty {
                Text("Select items to perform batch actions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(content200)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                HStack(spacing: 8) {
                    Spacer()

                    ManagementButton(
                        icon: Image(systemName: "minus.circle"),
                        text: "Deselect",
                        color: content100,
                        action: {
                            withAnimation(.snappy(duration: 0.25)) {
                                uiState.selectedItemIDs.removeAll()
                            }
                        }
                    )
                    .pointerCursor()

                    ManagementButton(
                        icon: Image(systemName: "arrow.up.right.square"),
                        text: "Open",
                        color: content100,
                        action: {
                            for item in selectedItems {
                                if let url = item.resolveURL() {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    )
                    .pointerCursor()

                    ManagementButton(
                        icon: Image(systemName: "magnifyingglass"),
                        text: "Reveal",
                        color: content100,
                        action: {
                            let urls = selectedItems.compactMap { $0.resolveURL() }
                            if !urls.isEmpty {
                                NSWorkspace.shared.activateFileViewerSelecting(urls)
                            }
                        }
                    )
                    .pointerCursor()

                    if !selectedImages.isEmpty {
                        ManagementButton(
                            icon: WandIcon(size: 11, weight: .bold),
                            text: "Convert",
                            color: .blue,
                            action: {
                                onConvertSelected(selectedItems)
                            }
                        )
                        .pointerCursor()
                    }

                    ManagementButton(
                        icon: Image(systemName: "trash"),
                        text: "Delete",
                        color: .red,
                        action: {
                            withAnimation(.snappy(duration: 0.25)) {
                                for id in uiState.selectedItemIDs {
                                    store.removeFile(id: id)
                                }
                                uiState.selectedItemIDs.removeAll()
                            }
                        }
                    )
                    .pointerCursor()

                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(height: 34)
        .padding(.horizontal, 14)
    }
}
