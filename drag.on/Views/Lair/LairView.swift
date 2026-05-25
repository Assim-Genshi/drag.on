import SwiftUI

// MARK: - LairView (Main Lair Overlay)

struct LairView: View {
    var store: LairStore
    var onClose: () -> Void
    var onConvert: () -> Void

    @State private var isHoveringConvert = false
    @AppStorage("compactMode") private var compactMode = false
    @Environment(\.openSettings) private var openSettings

    // MARK: - Theme Colors

    private var mainSurface: Color {
        Color("main-surfece")
    }

    private var secondarySurface: Color {
        Color("Secondary-surfece")
    }

    private var borderColor: Color {
        Color("border-color")
    }

    private var content100: Color {
        Color("content-100")
    }

    private var content200: Color {
        Color("content-200")
    }

    var body: some View {
        ZStack {
            if store.items.isEmpty {
                dashedContainerBorder
            }

            mainLairContent

            topBar
        }
        .background(
            RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius)
                .fill(mainSurface.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius)
                .stroke(borderColor, lineWidth: LairConstants.Convert.inputBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius))
        .onAppear {
            SettingsOpener.shared.register {
                openSettings()
            }
        }
    }

    // MARK: - Dashed Container Border

    private var dashedContainerBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(
                borderColor,
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
                    .fill(borderColor)
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .padding(.top, 4)
            .allowsHitTesting(false)

            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image("drag-on")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(content200)
                    Text("Drop Artifact here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(content200)
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

            if store.hasImages && !compactMode {
                Button(action: onConvert) {
                    HStack(spacing: 8) {
                        WandIcon(size: 13, weight: .bold)
                            .foregroundStyle(.white)
                        Text("Convert")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(content100)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        Capsule()
                            .fill(.skyblue)
                    )
                    .overlay(
                        Capsule()
                            .stroke(.cyanDream, lineWidth: 1.0)
                    )
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
                        if compactMode && store.hasImages {
                            Button(action: onConvert) {
                                Label("Convert Images…", systemImage: "wand.and.rays")
                            }
                        }

                        Button(role: .destructive, action: {
                            store.clearAll()
                        }) {
                            Label(LairConstants.Lair.clearActionText, systemImage: LairConstants.Lair.clearActionIcon)
                        }
                    } label: {
                        LairCircleButton(systemName: LairConstants.Lair.menuIconName)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
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
                .foregroundStyle(Color("content-100"))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color("content-100"))
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color("Secondary-surfece").opacity(LairConstants.Lair.buttonBackgroundOpacity))
        )
        .overlay(
            Capsule()
                .stroke(Color("border-color"), lineWidth: 1.0)
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
