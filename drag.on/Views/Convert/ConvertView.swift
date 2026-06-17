//
//  ConvertView.swift
//  drag.on
//
//  Created by assim on 2026-5-30.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ConvertView (Converter Dialog Content)

struct ConvertView: View {
    var store: LairStore
    var converter: ImageConverter
    var itemsToConvert: [FileItem]?
    var onDismiss: () -> Void

    @AppStorage("defaultFormat") private var defaultFormat: String = "WebP"
    @State private var selectedFormat: ImageFormat
    @State private var customOutputDir: URL? = nil
    @State private var useCustomOutput = false
    @State private var quality: Double = 0.85

    init(store: LairStore, converter: ImageConverter, itemsToConvert: [FileItem]? = nil, onDismiss: @escaping () -> Void) {
        self.store = store
        self.converter = converter
        self.itemsToConvert = itemsToConvert
        self.onDismiss = onDismiss
        
        let savedFormat = UserDefaults.standard.string(forKey: "defaultFormat") ?? "WebP"
        let initialFormat = ImageFormat.allCases.first(where: { $0.rawValue == savedFormat }) ?? .webp
        self._selectedFormat = State(initialValue: initialFormat)
        
        let mode = UserDefaults.standard.string(forKey: "defaultOutputMode") ?? "sameFolder"
        let customPath = UserDefaults.standard.string(forKey: "customOutputDirectoryPath") ?? ""
        
        let initialUseCustom: Bool
        let initialCustomDir: URL?
        
        switch mode {
        case "downloads":
            initialUseCustom = true
            initialCustomDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        case "custom":
            if !customPath.isEmpty {
                initialUseCustom = true
                initialCustomDir = URL(fileURLWithPath: customPath)
            } else {
                initialUseCustom = false
                initialCustomDir = nil
            }
        default: // "sameFolder"
            initialUseCustom = false
            initialCustomDir = nil
        }
        
        self._useCustomOutput = State(initialValue: initialUseCustom)
        self._customOutputDir = State(initialValue: initialCustomDir)
    }

    @State private var isHoveringConvert = false
    @State private var isHoveringCancel = false

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors

    private var primaryTextColor: Color {
        Color("content-100")
    }
    
    private var surfeceColor: Color {
        Color("main-surfece")
    }

    private var secondaryTextColor: Color {
        Color("content-200")
    }

    private var accentColor: Color { mainAccent }

    private var cardBackground: Color {
        Color("Secondary-surfece")
    }

    private var cardBorder: Color {
        Color("border-color")
    }

    @AppAccent(.main) private var mainAccent
    @AppAccent(.secondary) private var secondaryAccent

    private var imagesToConvert: [FileItem] {
        (itemsToConvert ?? store.items).filter(\.isImage)
    }

    var body: some View {
        Group {
            switch converter.state {
            case .idle, .validating:
                converterSettings
            case .converting(let progress):
                ConvertProgressView(progress: progress, converter: converter)
            case .success(let results):
                ConvertSuccessView(results: results, store: store, onDismiss: dismiss)
            case .failed(let message, let partialResults):
                ConvertFailureView(message: message, partialResults: partialResults, onDismiss: dismiss)
            }
        }
        .tint(mainAccent)
        .frame(width: LairConstants.Convert.width, height: LairConstants.Convert.height)
        .background(
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: LairConstants.Convert.cornerRadius)
                    .fill((surfeceColor).opacity(60))
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
            let imageItems = imagesToConvert
            converter.previewOutputDirectory(for: imageItems, customDir: useCustomOutput ? customOutputDir : nil)
        }
    }

    // MARK: - Settings

    private var converterSettings: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 2) {
                Text("Convert")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(primaryTextColor)
               
            }
            .padding(.bottom, 12)
            .padding(.top, 24)
            
            if !imagesToConvert.isEmpty {
                stackedPreviews
                    .padding(.bottom, 14)
                HStack{
                    let imageCount = imagesToConvert.count
                    Text("\(imageCount) image\(imageCount == 1 ? "" : "s") selected")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill(Color("Secondary-surfece").opacity(LairConstants.Lair.buttonBackgroundOpacity))
                )
                .overlay(
                    Capsule()
                        .stroke(Color("border-color").opacity(LairConstants.Lair.buttonBorderOpacity), lineWidth: 1.0)
                )
            } else {
                Spacer().frame(height: 18)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Format selector
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                        Text("FORMAT")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(primaryTextColor.opacity(0.7))
                            
                            Text("Select the target file type for conversion")
                                .font(.system(size: 9))
                                .foregroundStyle(secondaryTextColor)
                                .padding(.leading, 2)
                        }
                        Spacer()
                        
                        Menu {
                            ForEach(Array(ImageFormat.allCases.enumerated()), id: \.element.id) { pair in
                                Button(action: { selectedFormat = pair.element }) {
                                    VStack(alignment: .leading) {
                                        Text(pair.element.rawValue)
                                        Text(pair.element.formatDescription)
                                    }
                                }
                                if pair.offset < ImageFormat.allCases.count - 1 {
                                    Divider()
                                }
                            }
                        } label: {
                            SelectorInputLabel(selectedFormat.rawValue, systemImage: "doc.badge.gearshape", hasShadow: true, accentColor: accentColor)
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .pointerCursor()
                    }
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
                            .padding(.leading, 2)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Output location
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OUTPUT")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(primaryTextColor.opacity(0.7))
                            
                            Text("Where the converted files will be saved")
                                .font(.system(size: 9))
                                .foregroundStyle(secondaryTextColor)
                                .padding(.leading, 2)
                        }
                        
                        Spacer()
                        
                        Button(action: pickCustomFolder) {
                            SelectorInputLabel(outputLabel, showChevron: false, hasShadow: true) {
                                FolderIconPreviewView(url: outputFolderURL)
                            }
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .pointerCursor()
                    }
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
                            Capsule().stroke(Color.border.opacity(0.8), lineWidth: 1.0)
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
                                    secondaryAccent,
                                    mainAccent,
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
                                        .init(color: mainAccent, location: 0.5),
                                        .init(color: mainAccent.opacity(0.2), location: 1.0)
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
                    .shadow(color: mainAccent.opacity(0.35), radius: 12, x: 0, y: 6)
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

    private var outputFolderURL: URL? {
        if useCustomOutput, let dir = customOutputDir {
            return dir
        }
        return converter.resolvedOutput?.url
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
            converter.previewOutputDirectory(for: imagesToConvert, customDir: url)
        }
    }

    private func startConversion() {
        let outputDir = useCustomOutput ? customOutputDir : nil
        let imageItems = imagesToConvert
        converter.convertFiles(items: imageItems, format: selectedFormat, quality: quality, outputDir: outputDir)
    }

    private func dismiss() {
        converter.reset()
        onDismiss()
    }

    private var stackedPreviews: some View {
        let urls = imagesToConvert.prefix(3).compactMap { $0.resolveURL() }
        return ZStack {
            ForEach(0..<urls.count, id: \.self) { index in
                ConvertPreviewCard(url: urls[index], index: index, count: urls.count)
            }
        }
        .frame(height: 64)
    }
}

// MARK: - Convert Preview Card

struct ConvertPreviewCard: View {
    let url: URL
    let index: Int
    let count: Int

    @State private var animateIn = false

    private var rotationAngle: Angle {
        if count == 1 {
            return .degrees(0)
        } else if count == 2 {
            return index == 0 ? .degrees(-6) : .degrees(6)
        } else {
            if index == 0 {
                return .degrees(-8)
            } else if index == 1 {
                return .degrees(-2)
            } else {
                return .degrees(8)
            }
        }
    }

    private var xOffset: CGFloat {
        if count == 1 {
            return 0
        } else if count == 2 {
            return index == 0 ? -16 : 16
        } else {
            if index == 0 {
                return -28
            } else if index == 1 {
                return 0
            } else {
                return 28
            }
        }
    }

    private var yOffset: CGFloat {
        if count == 1 {
            return 0
        } else if count == 2 {
            return 2
        } else {
            if index == 0 {
                return 6
            } else if index == 1 {
                return 0
            } else {
                return 6
            }
        }
    }

    var body: some View {
        AsyncThumbnailView(url: url, size: CGSize(width: 120, height: 120))
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .background(Color("Secondary-surfece"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("border-color"), lineWidth: 1.0)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .rotationEffect(animateIn ? rotationAngle : .degrees(0))
            .offset(x: animateIn ? xOffset : 0, y: animateIn ? yOffset : 20)
            .opacity(animateIn ? 1 : 0)
            .zIndex(Double(index))
            .onAppear {
                withAnimation(.spring(duration: 0.55, bounce: 0.35).delay(Double(index) * 0.08)) {
                    animateIn = true
                }
            }
    }
}


