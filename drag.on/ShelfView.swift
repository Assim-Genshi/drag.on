import SwiftUI

// MARK: - ShelfView (Main Lair Overlay)

struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    var onClose: () -> Void
    var onConvert: () -> Void

    @State private var isHoveringConvert = false

    var body: some View {
        ZStack {
            // Layer 1: Dashed inner container border (only visible when empty)
            if store.items.isEmpty {
                dashedContainerBorder
            }

            // Layer 2: Main content
            mainShelfContent

            // Layer 3: Top bar (close + chevron)
            topBar
        }
    }

    // MARK: - Dashed Container Border

    private var dashedContainerBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                Color.white.opacity(0.18),
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 48) // Shift down to make space for top bar buttons above the guide
            .allowsHitTesting(false)
    }

    // MARK: - Main Shelf Content

    private var mainShelfContent: some View {
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
                // Empty state centered exactly inside the dashed container guides
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Drop Artifact here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 48)
            } else {
                // Space for the AppKit pile view (rendered underneath)
                Spacer()

                // Bottom bar
                bottomBar
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // File count button — always takes full width at bottom
            FileCountLabel(items: store.items)

            if allItemsAreImages {
                // Convert button — styled like a cloudy sky (glassy base + glowing center) - stacked below
                Button(action: onConvert) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.sparkles")
                            .font(.system(size: 13, weight: .bold))
                        Text("Convert")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        ZStack {
                            // Glass base
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                            
                            // Glowing cloudy center
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.1, green: 0.55, blue: 1.0, opacity: 0.95),
                                    Color(red: 0.3, green: 0.7, blue: 1.0, opacity: 0.15)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        }
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.0)
                    )
                    .shadow(color: Color(red: 0.0, green: 0.4, blue: 1.0).opacity(0.2), radius: 4, x: 0, y: 2)
                    .scaleEffect(isHoveringConvert ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHoveringConvert = hovering
                    }
                }
            }
        }
        .padding(.horizontal, 12) // Perfectly symmetric 12pt padding matching guideline and top bar
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                // Reusable circular Close button
                LairCircleButton(systemName: "xmark", action: onClose)

                Spacer()

                if !store.items.isEmpty {
                    // Reusable circular Chevron button (matching styling and hover logic)
                    LairCircleButton(systemName: "chevron.down", action: {})
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12) // Symmetric 12pt padding
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private var allItemsAreImages: Bool {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "svg", "ico"]
        return !store.items.isEmpty && store.items.allSatisfy { item in
            let ext = (item.fileName as NSString).pathExtension.lowercased()
            return imageExts.contains(ext)
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
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.95))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1.0)
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
