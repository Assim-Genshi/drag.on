import MetalKit
import simd
import SwiftUI

// MARK: - ShaderBackgroundView

/// A SwiftUI view that renders a flowing Metal shader animation using the app's current accent colors.
///
/// The shader starts/stops rendering based on window focus to conserve energy.
/// An optional bottom-fade mask can be applied for panels like the Convert view.
/// A gradient from `mainAccent → secondaryAccent` is always drawn behind the shader
/// so the background is visible immediately while Metal initializes.
struct ShaderBackgroundView: View {
    /// The height of the shader region.
    var height: CGFloat = 150

    /// When `true`, the shader fades to transparent at the bottom (for the Convert panel).
    var fadeToBottom: Bool = false

    @AppAccent(.main) private var mainAccent
    @AppAccent(.secondary) private var secondaryAccent

    @State private var isShown = false
    @State private var renderID = UUID()

    var body: some View {
        ZStack {
            // Accent gradient background — visible instantly, no GPU wait
            LinearGradient(
                colors: [mainAccent, secondaryAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Metal shader overlay (when ready)
            if isShown && MetalShaderCache.shared.isAvailable {
                AccentMetalShaderView(
                    color1: resolveColor(mainAccent),
                    color2: resolveColor(secondaryAccent)
                )
                .id(renderID)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .mask(fadeMask)
        .animation(.easeIn(duration: 0.3), value: isShown)
        .onAppear {
            isShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            if !isShown {
                renderID = UUID()
                isShown = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { _ in
            isShown = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            isShown = false
        }
    }

    // MARK: - Fade Mask

    @ViewBuilder
    private var fadeMask: some View {
        if fadeToBottom {
            // Fade from opaque at top to transparent at bottom (for ConvertView)
            LinearGradient(
                gradient: Gradient(colors: [.white, .white, .white.opacity(0.8), .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Fade from transparent at very top to opaque (for SettingsView header)
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.55),
                    .init(color: .white, location: 1),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Color Resolution

    /// Converts a SwiftUI `Color` to a `simd_float4` for the Metal shader.
    private func resolveColor(_ color: Color) -> simd_float4 {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else {
            return simd_float4(0.3, 0.6, 1.0, 1.0) // Fallback blue
        }
        return simd_float4(
            Float(rgb.redComponent),
            Float(rgb.greenComponent),
            Float(rgb.blueComponent),
            Float(rgb.alphaComponent)
        )
    }
}
