import SwiftUI

public struct TourSlideshowView: View {
    public let pages: [TourPage]
    public let continueButtonTitle: LocalizedStringKey
    public let finishButtonTitle: LocalizedStringKey
    public let onFinish: () -> Void
    public let onClose: () -> Void

    @State private var currentPageIndex: Int = 0
    @State private var isHoveringClose = false
    @State private var isHoveringPrimary = false

    public init(
        pages: [TourPage],
        continueButtonTitle: LocalizedStringKey = "Continue",
        finishButtonTitle: LocalizedStringKey = "Get Started",
        onFinish: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.pages = pages
        self.continueButtonTitle = continueButtonTitle
        self.finishButtonTitle = finishButtonTitle
        self.onFinish = onFinish
        self.onClose = onClose
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Content Area
            VStack(spacing: 0) {
                // Top Half: Artwork/Image Area with smooth carousel
                ZStack(alignment: .bottom) {
                    if !pages.isEmpty {
                        let page = pages[currentPageIndex]
                        
                        // Slide image with fallback placeholder
                        Group {
                            if let nsImage = NSImage(named: page.imageName) ?? (page.imageBundle?.image(for: page.imageName)) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                // Premium, minimal placeholder card
                                ZStack {
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.25), Color.black.opacity(0.4)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    
                                    VStack(spacing: 16) {
                                        // Dynamic icon selection based on slide index
                                        Image(systemName: iconForIndex(currentPageIndex))
                                            .font(.system(size: 64, weight: .ultraLight))
                                            .foregroundStyle(
                                                .linearGradient(
                                                    colors: [Color(hex: "4EA3FF") ?? .blue, Color(hex: "95D7FD") ?? .cyan],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: (Color(hex: "4EA3FF") ?? .blue).opacity(0.3), radius: 12)
                                        
                                        VStack(spacing: 4) {
                                            Text("Artwork Placeholder")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(page.imageName)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                        .id(currentPageIndex) // Key to trigger transition animation on page change
                    }
                    
                    // Gradient Mask to blend image into the dark bottom panel
                    LinearGradient(
                        colors: [.clear, Color(hex: "13151A") ?? .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 70)
                }
                .frame(height: 250)
                
                // Bottom Half: Content panel
                VStack(spacing: 0) {
                    if !pages.isEmpty {
                        let page = pages[currentPageIndex]
                        
                        VStack(spacing: 12) {
                            Text(page.title)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                .id("title-\(currentPageIndex)")
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            
                            Text(page.description)
                                .font(.system(size: 13.5, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .frame(height: 54, alignment: .top)
                                .padding(.horizontal, 40)
                                .id("desc-\(currentPageIndex)")
                                .transition(.opacity)
                        }
                        .animation(.easeOut(duration: 0.35), value: currentPageIndex)
                    }
                    
                    Spacer()
                    
                    // Footer Controls (Indicators & Button)
                    HStack(spacing: 0) {
                        // Custom animated page indicators
                        HStack(spacing: 6) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Capsule()
                                    .fill(currentPageIndex == index ? (Color(hex: "4EA3FF") ?? .blue) : Color.white.opacity(0.2))
                                    .frame(width: currentPageIndex == index ? 18 : 6, height: 6)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPageIndex)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                            currentPageIndex = index
                                        }
                                    }
                                    .pointerCursor()
                            }
                        }
                        
                        Spacer()
                        
                        // Action Button
                        Button(action: {
                            handlePrimaryAction()
                        }) {
                            Text(currentPageIndex == pages.count - 1 ? finishButtonTitle : continueButtonTitle)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "4EA3FF") ?? .blue, Color(hex: "95D7FD") ?? .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(10)
                                .shadow(color: (Color(hex: "4EA3FF") ?? .blue).opacity(isHoveringPrimary ? 0.4 : 0.2), radius: isHoveringPrimary ? 8 : 4)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isHoveringPrimary ? 1.02 : 1.0)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                isHoveringPrimary = hovering
                            }
                        }
                        .pointerCursor()
                    }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(Color(hex: "13151A") ?? Color(white: 0.08))
            }
            
            // Top Right: Translucent Close Button
            Button(action: {
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(isHoveringClose ? 1.0 : 0.4))
                    .frame(width: 26, height: 26)
                    .background(Color.black.opacity(isHoveringClose ? 0.3 : 0.15))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(16)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHoveringClose = hovering
                }
            }
            .pointerCursor()
        }
        .frame(width: 600, height: 440)
        .preferredColorScheme(.dark)
    }

    private func handlePrimaryAction() {
        if currentPageIndex < pages.count - 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentPageIndex += 1
            }
        } else {
            onFinish()
        }
    }
    
    // Choose appropriate system symbol for placeholder slide art
    private func iconForIndex(_ index: Int) -> String {
        switch index {
        case 0: return "hand.draw"
        case 1: return "square.stack.3d.down.forward"
        case 2: return "wand.and.sparkles"
        case 3: return "keyboard"
        case 4: return "slider.horizontal.3"
        default: return "sparkles"
        }
    }
}

// Helper to resolve images inside a specific bundle if needed
extension Bundle {
    func image(for resourceName: String) -> NSImage? {
        if let path = self.path(forResource: resourceName, ofType: nil) {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }
}
