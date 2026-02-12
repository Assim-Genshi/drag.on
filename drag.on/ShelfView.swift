import SwiftUI

enum WindowDragEvent {
    case began
    case changed(CGSize)
    case ended
}

struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    var onClose: () -> Void
    var onWindowDrag: (WindowDragEvent) -> Void = { _ in }

    @State private var isDraggingWindowBackground = false

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(backgroundDragGesture)

            VStack(spacing: 0) {
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
                    Spacer()
                    Text("Drop Artifact here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                } else {
                    ArtifactGridView(items: store.items)
                        .padding(.top, 14)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    FileCountLabel(items: store.items)
                        .padding(.bottom, 10)
                }
            }

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

                    if !store.items.isEmpty {
                        Button(action: {}) {
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

    private var backgroundDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDraggingWindowBackground {
                    isDraggingWindowBackground = true
                    onWindowDrag(.began)
                }
                onWindowDrag(.changed(value.translation))
            }
            .onEnded { _ in
                guard isDraggingWindowBackground else { return }
                isDraggingWindowBackground = false
                onWindowDrag(.ended)
            }
    }
}

struct ArtifactGridView: View {
    let items: [FileItem]

    private let columns = [
        GridItem(.adaptive(minimum: 74, maximum: 90), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    FileThumbnailCard(item: item)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.never)
    }
}

struct FileThumbnailCard: View {
    let item: FileItem

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: item.thumbnail())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 58, height: 58)
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
                return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider()
        }
    }
}

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
