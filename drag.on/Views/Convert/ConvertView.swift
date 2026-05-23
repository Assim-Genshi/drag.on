import SwiftUI

// MARK: - ConvertView (Converter Dialog Content)

struct ConvertView: View {
    var store: LairStore
    var converter: ImageConverter
    var onDismiss: () -> Void

    @State private var selectedFormat: ImageFormat = .webp
    @State private var customOutputDir: URL? = nil
    @State private var useCustomOutput = false

    @State private var isHoveringConvert = false
    @State private var isHoveringAdd = false
    @State private var isHoveringClearAdd = false
    @State private var isHoveringReveal = false
    @State private var isHoveringDismiss = false

    // MARK: - Theme Colors

    private var primaryTextColor: Color {
        Color(red: 0.05, green: 0.22, blue: 0.45)
    }

    private var secondaryTextColor: Color {
        Color.black.opacity(0.55)
    }

    private var accentColor: Color {
        Color(red: 0.0, green: 0.55, blue: 1.0)
    }

    private var cardBackground: Color {
        Color.black.opacity(0.04)
    }

    private var cardBorder: Color {
        Color.black.opacity(0.06)
    }

    var body: some View {
        Group {
            switch converter.state {
            case .idle:
                converterSettings
            case .converting(let current, let index, let total):
                convertingProgress(current: current, index: index, total: total)
            case .success(let urls):
                conversionSuccess(urls: urls)
            case .failed(let message):
                conversionFailed(message: message)
            }
        }
        .frame(width: 320, height: 380)
        .background(
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                Image("sky_clouds_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 320, height: 160)
                    .clipped()
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .black, .black.opacity(0.8), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.85)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 36))
        .onAppear {
            converter.previewOutputDirectory(for: store.items, customDir: nil)
        }
    }

    // MARK: - Settings

    private var converterSettings: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    LairCircleButton(systemName: "xmark", action: dismiss, isLightBackground: true)
                    Spacer()
                }
                VStack(alignment: .center, spacing: 2) {
                    Text("Convert")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(primaryTextColor)
                    Text("\(store.items.count) image\(store.items.count == 1 ? "" : "s") selected")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 6) {
                Text("FORMAT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(primaryTextColor.opacity(0.7))
                    .tracking(1.0)
                Menu {
                    ForEach(ImageFormat.allCases) { format in
                        Button(action: { selectedFormat = format }) {
                            Text(format.rawValue)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.system(size: 12))
                            .foregroundStyle(accentColor)
                        Text(selectedFormat.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(secondaryTextColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(cardBackground))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("OUTPUT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(primaryTextColor.opacity(0.7))
                    .tracking(1.0)
                HStack(spacing: 8) {
                    Image(systemName: outputIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(isWebDrop ? accentColor : secondaryTextColor.opacity(0.8))
                    Text(outputLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(action: pickCustomFolder) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12))
                            .foregroundStyle(secondaryTextColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: 0.5))
            }
            .padding(.horizontal, 16)

            Spacer()

            Button(action: startConversion) {
                HStack(spacing: 8) {
                    WandIcon(size: 13, weight: .bold)
                    Text("Convert Now")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.306, green: 0.639, blue: 1.0),
                                Color(red: 0.584, green: 0.843, blue: 0.992)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                )
                .overlay(Capsule().stroke(Color(red: 0.553, green: 0.820, blue: 0.992, opacity: 0.58), lineWidth: 2))
                .overlay(
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.0)], startPoint: .topTrailing, endPoint: .bottomLeading))
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                )
                .shadow(color: Color(red: 0.306, green: 0.639, blue: 1.0).opacity(0.35), radius: 12, x: 0, y: 6)
                .scaleEffect(isHoveringConvert ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.easeOut(duration: 0.15)) { isHoveringConvert = h }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Progress

    private func convertingProgress(current: String, index: Int, total: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.0)
            Text("Converting...")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)
            Text(current)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 24)
            Text("\(index + 1) of \(total)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(secondaryTextColor.opacity(0.7))
            Spacer()
        }
    }

    // MARK: - Success

    private func conversionSuccess(urls: [URL]) -> some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 20)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(accentColor)
            Text("Conversion Complete")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)
            Text("\(urls.count) file\(urls.count == 1 ? "" : "s") created")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(urls, id: \.absoluteString) { url in
                        GhostCardView(url: url)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 76)
            .padding(.horizontal, 16)

            Spacer()

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Button(action: {
                        store.addFiles(urls: urls)
                        dismiss()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Add to Lair")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(accentColor))
                        .shadow(color: accentColor.opacity(0.2), radius: 3, x: 0, y: 2)
                        .scaleEffect(isHoveringAdd ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeOut(duration: 0.15)) { isHoveringAdd = h }
                    }

                    Button(action: {
                        store.clearAll()
                        store.addFiles(urls: urls)
                        dismiss()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.3.trianglepath")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Clear & Add")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                        .scaleEffect(isHoveringClearAdd ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeOut(duration: 0.15)) { isHoveringClearAdd = h }
                    }
                }
                .padding(.horizontal, 16)

                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                        Text("Reveal in Finder")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(secondaryTextColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Capsule().fill(cardBackground))
                    .scaleEffect(isHoveringReveal ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.easeOut(duration: 0.15)) { isHoveringReveal = h }
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Failure

    private func conversionFailed(message: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color(red: 0.95, green: 0.4, blue: 0.1))
            Text("Conversion Failed")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)
            Text(message)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 24)
            Spacer()
            Button(action: dismiss) {
                Text("Dismiss")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(cardBackground))
                    .scaleEffect(isHoveringDismiss ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { h in
                withAnimation(.easeOut(duration: 0.15)) { isHoveringDismiss = h }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Helpers

    private var outputLabel: String {
        if useCustomOutput, let dir = customOutputDir {
            return dir.lastPathComponent
        }
        return converter.resolvedOutput?.label ?? "Same Folder"
    }

    private var outputIcon: String {
        isWebDrop && !useCustomOutput ? "arrow.down.circle" : "folder"
    }

    private var isWebDrop: Bool {
        converter.resolvedOutput?.isWebDrop == true && !useCustomOutput
    }

    private func pickCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose output folder for converted files"
        if panel.runModal() == .OK, let url = panel.url {
            customOutputDir = url
            useCustomOutput = true
        }
    }

    private func startConversion() {
        let outputDir = useCustomOutput ? customOutputDir : nil
        converter.convertFiles(items: store.items, format: selectedFormat, outputDir: outputDir)
    }

    private func dismiss() {
        converter.reset()
        onDismiss()
    }
}

// MARK: - Ghost Card

struct GhostCardView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
            Text(url.lastPathComponent)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.65))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 58)
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
    }
}
