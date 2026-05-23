import SwiftUI

// MARK: - LairView (Main Lair Overlay)

struct LairView: View {
    var store: LairStore
    var onClose: () -> Void
    var onConvert: () -> Void

    @State private var isHoveringConvert = false

    var body: some View {
        ZStack {
            if store.items.isEmpty {
                dashedContainerBorder
            }

            mainLairContent

            topBar
        }
    }

    // MARK: - Dashed Container Border

    private var dashedContainerBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                Color.white.opacity(0.18),
                style: StrokeStyle(lineWidth: 1.5, dash: [9, 4])
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 52)
            .allowsHitTesting(false)
    }

    // MARK: - Main Lair Content

    private var mainLairContent: some View {
        VStack(spacing: 0) {
            // Drag handle pill
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
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("Drop Artifact here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 48)
            } else {
                Spacer()

                bottomBar
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            FileCountLabel(items: store.items)

            if store.allItemsAreImages {
                Button(action: onConvert) {
                    HStack(spacing: 8) {
                        WandIcon(size: 13, weight: .bold)
                        Text("Convert")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
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
        .padding(.horizontal, 12)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                LairCircleButton(systemName: "xmark", action: onClose)

                Spacer()

                if !store.items.isEmpty {
                    Menu {
                        Button(role: .destructive, action: {
                            store.clearAll()
                        }) {
                            Label("Clear Lair", systemImage: "trash")
                        }
                    } label: {
                        LairCircleButton(systemName: "chevron.down", action: {})
                    }
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}

// MARK: - File Count Label

struct FileCountLabel: View {
    let items: [FileItem]

    var body: some View {
        HStack(spacing: 4) {
            Text(countText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
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

    private var countText: String {
        let count = items.count
        if count == 1 {
            return "1 File"
        }
        let allImages = items.allSatisfy { SupportedImageExtensions.isImage(fileName: $0.fileName) }
        return allImages ? "\(count) Images" : "\(count) Files"
    }
}
