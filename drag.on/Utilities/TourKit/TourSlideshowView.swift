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
    @State private var isHoveringBack = false

    @AppAccent(.main) private var mainAccent
    @AppAccent(.secondary) private var secondaryAccent

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
        ZStack(alignment: .topLeading) {
            // Main Content Area
            VStack(spacing: 0) {
                // Top Half: Artwork/Image Area with smooth carousel
                ZStack(alignment: .bottom) {
                    if !pages.isEmpty {
                        let page = pages[currentPageIndex]
                        
                        // Slide image with fallback placeholder
                        Group {
                            if currentPageIndex == 0 {
                                Image("app-icon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                            } else if let nsImage = NSImage(named: page.imageName) ?? (page.imageBundle?.image(for: page.imageName)) {
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
                                                    colors: [secondaryAccent, accentColor],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: accentColor.opacity(0.3), radius: 12)
                                        
                                        VStack(spacing: 4) {
                                            Text("Artwork Placeholder")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(primaryTextColor.opacity(0.7))
                                            Text(page.imageName)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(secondaryTextColor.opacity(0.5))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .black, location: 0.9),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                        .id(currentPageIndex) // Key to trigger transition animation on page change
                    }
                    
                    // Gradient Mask to blend image into the main surface bottom panel (made stronger)
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: surfeceColor.opacity(0.85), location: 0.65),
                            .init(color: surfeceColor, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                }
                .frame(height: 230)
                
                // Bottom Half: Content panel
                VStack(spacing: 0) {
                    if !pages.isEmpty {
                        let page = pages[currentPageIndex]
                        
                        VStack(spacing: 8) {
                            Text(page.title)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(primaryTextColor)
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                .id("title-\(currentPageIndex)")
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            
                            Text(page.description)
                                .font(.system(size: 13.5, weight: .regular))
                                .foregroundColor(secondaryTextColor)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .frame(height: 54, alignment: .top)
                                .padding(.horizontal, 40)
                                .id("desc-\(currentPageIndex)")
                                .transition(.opacity)
                        }
                        .padding(.top, 20) // Give the title a little margin from the top
                        .animation(.easeOut(duration: 0.35), value: currentPageIndex)
                    }
                    
                    Spacer()
                    
                    // Center stacked Indicators and Action Buttons
                    VStack(spacing: 16) {
                        // Custom animated page indicators on top of the button
                        HStack(spacing: 6) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Capsule()
                                    .fill(currentPageIndex == index ? accentColor : secondaryTextColor.opacity(0.3))
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
                        
                        // Action Buttons matching ConvertView's premium style
                        HStack(spacing: 12) {
                            if currentPageIndex > 0 {
                                Button(action: {
                                    handleBackAction()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: 12, weight: .bold))
                                        Text("Back")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundStyle(primaryTextColor.opacity(0.9))
                                    .frame(width: 100)
                                    .padding(.vertical, 14)
                                    .background(
                                        Capsule().fill(cardBackground)
                                    )
                                    .overlay(
                                        Capsule().stroke(cardBorder.opacity(0.8), lineWidth: 1.0)
                                    )
                                    .scaleEffect(isHoveringBack ? 1.03 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .onHover { h in
                                    withAnimation(.easeOut(duration: 0.15)) { isHoveringBack = h }
                                }
                                .pointerCursor()
                            }
                            
                            Button(action: {
                                handlePrimaryAction()
                            }) {
                                HStack(spacing: 8) {
                                    if currentPageIndex == pages.count - 1 {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    Text(currentPageIndex == pages.count - 1 ? finishButtonTitle : continueButtonTitle)
                                        .font(.system(size: 13, weight: .bold))
                                    if currentPageIndex < pages.count - 1 {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(width: 220)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                secondaryAccent,
                                                accentColor,
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
                                                    .init(color: accentColor, location: 0.5),
                                                    .init(color: accentColor.opacity(0.2), location: 1.0)
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
                                .shadow(color: accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
                                .scaleEffect(isHoveringPrimary ? 1.03 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    isHoveringPrimary = hovering
                                }
                            }
                            .pointerCursor()
                        }
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .background(surfeceColor)
            }
            
            // Top Left: Reusable LairCircleButton
            LairCircleButton(systemName: "xmark", action: onClose)
                .padding(16)
                .pointerCursor()
        }
        .frame(width: 600, height: 440)
        .background(surfeceColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(cardBorder, lineWidth: 1.0)
        )
        .topHighlightBorder(cornerRadius: 24)
        .tint(accentColor)
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
    
    private func handleBackAction() {
        if currentPageIndex > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                currentPageIndex -= 1
            }
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
