import SwiftUI

struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    var onClose: () -> Void

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Top drag handle pill
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 4)
                    Spacer()
                }
                .padding(.top, 4)
                .allowsHitTesting(false)

                if store.items.isEmpty {
                    // Empty state
                    Spacer()
                    Text("Drop Artifact here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                } else {
                    // Stacked thumbnails — pile of cards
                    Spacer()
                    FilePileView(items: store.items)
                        .frame(maxWidth: .infinity)
                    Spacer()

                    // Bottom label — file count
                    FileCountLabel(items: store.items)
                        .padding(.bottom, 10)
                }
            }

            // Close button — top left
            VStack {
                HStack {
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                     .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                )

                    Spacer()

                    // Chevron button — top right (expand/browse)
                    if !store.items.isEmpty {
                        Button(action: {
                            // Could open a detailed list view later
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                         .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
    }
}

// MARK: - Stacked thumbnail pile

struct FilePileView: View {
    let items: [FileItem]

    var body: some View {
        let displayItems = Array(items.suffix(5)) // Show last 5 max
        let count = displayItems.count

        ZStack {
            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                let offset = count - 1 - index // Reverse so newest is on top
                let rotation = cardRotation(for: offset, total: count)
                let yOffset = CGFloat(offset) * 2

                FileThumbnailCard(item: item)
                    .rotationEffect(.degrees(rotation), anchor: .center)
                    .offset(y: yOffset)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    .zIndex(Double(index))
            }
        }
        .padding(.horizontal, 30)
    }

    private func cardRotation(for index: Int, total: Int) -> Double {
        if total <= 1 { return 0 }
        // Alternate left/right rotation for a natural pile feel
        let rotations: [Double] = [0, -6, 5, -3, 7]
        return rotations[index % rotations.count]
    }
}

// MARK: - Single thumbnail card

struct FileThumbnailCard: View {
    let item: FileItem

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: item.thumbnail())
                .resizable()
                .aspectRatio(contentMode: .fit)
                //make the max height to be 90
                .frame(width: 90)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .onDrag {
            if let url = item.resolveURL() {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider()
        }
    }
}

// MARK: - Bottom file count label

struct FileCountLabel: View {
    let items: [FileItem]

    var body: some View {
        let label = countText()

        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func countText() -> String {
        let count = items.count
        if count == 1 {
            return "1 File"
        } else {
            // Check if all are images
            let imageExts = Set(["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp", "svg"])
            let allImages = items.allSatisfy { item in
                let ext = (item.fileName as NSString).pathExtension.lowercased()
                return imageExts.contains(ext)
            }
            if allImages {
                return "\(count) Images"
            }
            return "\(count) Files"
        }
    }
}
