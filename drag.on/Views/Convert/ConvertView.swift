import SwiftUI
import UniformTypeIdentifiers

// MARK: - ConvertView (Converter Dialog Content)

struct ConvertView: View {
    var store: LairStore
    var converter: ImageConverter
    var onDismiss: () -> Void

    @AppStorage("defaultFormat") private var defaultFormat: String = "WebP"
    @State private var selectedFormat: ImageFormat = .webp
    @State private var customOutputDir: URL? = nil
    @State private var useCustomOutput = false
    @State private var quality: Double = 0.85

    @State private var isHoveringConvert = false
    @State private var isHoveringCancel = false
    @State private var isHoveringAdd = false
    @State private var isHoveringClearAdd = false
    @State private var isHoveringReveal = false
    @State private var isHoveringDismiss = false

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors

    private var primaryTextColor: Color {
        Color("content-100")
    }

    private var secondaryTextColor: Color {
        Color("content-200")
    }

    private var accentColor: Color {
        Color(red: 0.0, green: 0.55, blue: 1.0)
    }

    private var cardBackground: Color {
        Color("Secondary-surfece")
    }

    private var cardBorder: Color {
        Color("border-color")
    }

    var body: some View {
        Group {
            switch converter.state {
            case .idle, .validating:
                converterSettings
            case .converting(let progress):
                convertingProgress(progress: progress)
            case .success(let results):
                conversionSuccess(results: results)
            case .failed(let message, let partialResults):
                conversionFailed(message: message, partialResults: partialResults)
            }
        }
        .frame(width: LairConstants.Convert.width, height: LairConstants.Convert.height)
        .background(
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: LairConstants.Convert.cornerRadius)
                    .fill(Color("main-surfece"))
                if colorScheme != .dark {
                    Image("sky_clouds_bg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: LairConstants.Convert.width, height: 160)
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
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LairConstants.Convert.cornerRadius))
        .onAppear {
            // Wire up the default format from settings
            if let savedFormat = ImageFormat.allCases.first(where: { $0.rawValue == defaultFormat }) {
                selectedFormat = savedFormat
            }
            let imageItems = store.items.filter(\.isImage)
            converter.previewOutputDirectory(for: imageItems, customDir: nil)
        }
    }

    // MARK: - Settings

    private var converterSettings: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 2) {
                Text("Convert")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(primaryTextColor)
                let imageCount = store.items.filter(\.isImage).count
                Text("\(imageCount) image\(imageCount == 1 ? "" : "s") selected")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(.top, 18)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 12) {
                // Format selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("FORMAT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(primaryTextColor.opacity(0.7))
                        .tracking(1.0)
                    Menu {
                        ForEach(ImageFormat.allCases) { format in
                            Button(action: { selectedFormat = format }) {
                                VStack(alignment: .leading) {
                                    Text(format.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.gearshape")
                                .font(.system(size: 12))
                                .foregroundStyle(accentColor)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(selectedFormat.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(primaryTextColor)
                                Text(selectedFormat.formatDescription)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(secondaryTextColor)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(cardBackground))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: LairConstants.Convert.inputBorderWidth))
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)
                    .pointerCursor()

                    Text("Select the target file type for conversion")
                        .font(.system(size: 9))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.top, 2)
                }

                // Quality slider — only for lossy formats
                if selectedFormat.supportsQuality {
                    VStack(alignment: .leading, spacing: 4) {
                        CapsuleSlider(
                            value: $quality,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            cardBackground: cardBackground,
                            cardBorder: cardBorder
                        )
                        .pointerCursor()

                        Text("Balance between file size and image fidelity")
                            .font(.system(size: 9))
                            .foregroundStyle(secondaryTextColor)
                            .padding(.top, 2)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Output location
                VStack(alignment: .leading, spacing: 4) {
                    Text("OUTPUT LOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(primaryTextColor.opacity(0.7))
                        .tracking(1.0)
                    
                    Button(action: pickCustomFolder) {
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
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 12))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(cardBackground))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: LairConstants.Convert.inputBorderWidth))
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()

                    Text("Where the converted files will be saved")
                        .font(.system(size: 9))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.2), value: selectedFormat.supportsQuality)

            Spacer()

            VStack(spacing: 8) {
                Button(action: dismiss) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(primaryTextColor.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(Color.secondarySurfece)
                        )
                        .overlay(
                            Capsule().stroke(Color.border.opacity(0.08), lineWidth: 1.0)
                        )
                        .scaleEffect(isHoveringCancel ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.easeOut(duration: 0.15)) { isHoveringCancel = h }
                }
                .pointerCursor()

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
                                    Color(.cyanDream),
                                    Color(.skyblue),
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white.opacity(0.85), location: 0.0),
                                        .init(color: Color(red: 0.1, green: 0.45, blue: 0.8, opacity: 0.45), location: 0.5),
                                        .init(color: Color(red: 0.4, green: 0.75, blue: 0.95, opacity: 0.65), location: 1.0)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
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
                .pointerCursor()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Progress

    private func convertingProgress(progress: ConversionProgress) -> some View {
        VStack(spacing: 16) {
            Spacer()

            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: progress.fractionComplete)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress.fractionComplete)

                Text("\(Int(progress.fractionComplete * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
            }

            VStack(spacing: 4) {
                Text(progress.phase.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text(progress.currentFileName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)

                Text("\(progress.currentIndex + 1) of \(progress.totalCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(secondaryTextColor.opacity(0.7))
            }

            Spacer()

            Button(action: {
                converter.cancelConversion()
            }) {
                Text("Cancel")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(cardBackground))
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .padding(.bottom, 16)
        }
    }

    // MARK: - Success

    private func conversionSuccess(results: [ConversionResult]) -> some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 20)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(accentColor)
            Text("Conversion Complete")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)
            Text("\(results.count) file\(results.count == 1 ? "" : "s") created")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(results, id: \.convertedURL.absoluteString) { result in
                        GhostCardView(url: result.convertedURL)
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
                        let urls = results.map(\.convertedURL)
                        store.addFilesAsync(urls: urls)
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
                    .pointerCursor()

                    Button(action: {
                        let urls = results.map(\.convertedURL)
                        store.clearAll()
                        store.addFilesAsync(urls: urls)
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
                    .pointerCursor()
                }
                .padding(.horizontal, 16)

                Button(action: {
                    let urls = results.map(\.convertedURL)
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
                .pointerCursor()
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Failure

    private func conversionFailed(message: String, partialResults: [ConversionResult]) -> some View {
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
                .lineLimit(4)
                .padding(.horizontal, 24)

            if !partialResults.isEmpty {
                Text("\(partialResults.count) file\(partialResults.count == 1 ? "" : "s") succeeded")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
            }

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
            .pointerCursor()
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
        let imageItems = store.items.filter(\.isImage)
        converter.convertFiles(items: imageItems, format: selectedFormat, quality: quality, outputDir: outputDir)
    }

    private func dismiss() {
        converter.reset()
        onDismiss()
    }
}

// MARK: - Async Thumbnail View

struct AsyncThumbnailView: View {
    let url: URL
    let size: CGSize

    @State private var image: NSImage? = nil

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
            } else {
                Image(nsImage: placeholderIcon)
                    .resizable()
            }
        }
        .task(id: url) {
            let isImage = SupportedImageExtensions.isImage(fileName: url.lastPathComponent)
            
            // Check cache synchronously first to avoid flash of placeholder
            if let cached = ThumbnailCache.shared.cachedImage(for: url.path) {
                self.image = cached
            } else {
                self.image = await ThumbnailCache.shared.thumbnail(
                    for: url.path,
                    url: url,
                    size: size,
                    isImage: isImage
                )
            }
        }
    }

    private var placeholderIcon: NSImage {
        if FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let type = UTType(filenameExtension: url.pathExtension) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }
}

// MARK: - Ghost Card

struct GhostCardView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 4) {
            AsyncThumbnailView(url: url, size: CGSize(width: 84, height: 84))
                .aspectRatio(contentMode: .fit)
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
