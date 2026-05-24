import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A custom, highly interactive capsule slider designed for premium UI tracking.
struct CapsuleSlider: View {
    @Binding var value: Double // Clamped between 0.05 and 1.0
    
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let cardBackground: Color
    let cardBorder: Color

    @Environment(\.colorScheme) private var colorScheme

    @State private var isHovered = false
    @State private var isDragging = false
    
    // States to manage trackpad haptic feedback and prevent duplicate triggers
    @State private var lastHapticPercentage: Int = -1
    @State private var hasTriggeredMinBoundary = false
    @State private var hasTriggeredMaxBoundary = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Handle has a constant premium thickness (more weight) of 6pt
            let handleWidth: CGFloat = 2
            
            // Base height scales dynamically in hover/drag states (only height changes between those states)
            let baseHandleHeight: CGFloat = isDragging ? height * 0.70 : (isHovered ? height * 0.65 : height * 0.50)
            
            // Mathematically track entering either the left "Quality" box or the right percentage box
            // Progress goes from 0.0 (fully visible) to 1.0 (completely disappeared)
            let disappearProgress: Double = {
                if value < 0.20 {
                    // Smoothly transition between 20% and 12% quality
                    return max(0.0, min(1.0, (0.20 - value) / 0.08))
                } else if value > 0.80 {
                    // Smoothly transition between 80% and 90% quality
                    return max(0.0, min(1.0, (value - 0.80) / 0.10))
                } else {
                    return 0.0
                }
            }()
            
            // Combine disappearing effect: opacity goes to 0%, height shrinks to 0
            let handleOpacity = 1.0 - disappearProgress
            let handleHeight = baseHandleHeight * CGFloat(1.0 - disappearProgress)
            
            ZStack(alignment: .leading) {
                // 1. Track Background
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isDragging ? Color(.skyblue).opacity(0.3) : (isHovered ? cardBorder.opacity(1.8) : cardBorder),
                                lineWidth: LairConstants.Convert.inputBorderWidth
                            )
                    )
                    .animation(.easeOut(duration: 0.2), value: isHovered)
                    .animation(.easeOut(duration: 0.2), value: isDragging)
                
                // 2. Base Label Layer (Adaptive text: visible when NOT covered by the active fill)
                HStack {
                    Text("Quality")
                        .foregroundStyle(secondaryTextColor.opacity(isDragging ? 0.85 : (isHovered ? 0.7 : 0.55)))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                    
                    Spacer()
                    
                    Text("\(Int(value * 100))%")
                        .foregroundStyle(secondaryTextColor.opacity(isDragging ? 0.85 : (isHovered ? 0.7 : 0.55)))
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                
                // 3. Active Fill Level (Solid .skyblue color)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.skyblue))
                    .frame(width: max(0, width * CGFloat(value)))
                
                // 4. Overlaid Label Layer (White text: masked to ONLY show when on top of the active fill)
                HStack {
                    Text("Quality")
                        .foregroundStyle(Color.white)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                    
                    Spacer()
                    
                    Text("\(Int(value * 100))%")
                        .foregroundStyle(Color.white)
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .mask(
                    Color.black
                        .frame(width: max(0, width * CGFloat(value)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                )
                
                // 5. Tactile Floating Handle (Pure White, disappears with combined fade + height shrink animation)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(isDragging ? 0.15 : 0.08), radius: isDragging ? 3 : 1.5, x: 0, y: 1)
                    .frame(width: handleWidth, height: handleHeight)
                    .offset(x: max(0, min(width - handleWidth, width * CGFloat(value) - 10)))
                    .opacity(handleOpacity)
                    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isDragging)
                    .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let dragLocation = gesture.location.x
                        // Mathematically align coordinates to handle center (reversing width * value - 10)
                        let percentage = Double((dragLocation + 10) / width)
                        let clampedPercentage = max(0.05, min(1.0, percentage))
                        
                        if clampedPercentage != self.value {
                            self.value = clampedPercentage
                            triggerHapticFeedback(for: clampedPercentage)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        // Reset boundary triggers on end of gesture
                        hasTriggeredMinBoundary = false
                        hasTriggeredMaxBoundary = false
                    }
            )
        }
        .frame(height: 36)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            // Ensure any existing values conform to the new minimum limit of 5%
            if value < 0.05 {
                value = 0.05
            }
        }
    }
    
    /// Triggers physical trackpad vibrations corresponding to the drag state
    private func triggerHapticFeedback(for clampedPercentage: Double) {
        #if os(macOS)
        // 1. Boundary Alignment snap feel at 5% and 100%
        if clampedPercentage <= 0.05 {
            if !hasTriggeredMinBoundary {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                hasTriggeredMinBoundary = true
            }
        } else {
            hasTriggeredMinBoundary = false
        }
        
        if clampedPercentage >= 1.0 {
            if !hasTriggeredMaxBoundary {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                hasTriggeredMaxBoundary = true
            }
        } else {
            hasTriggeredMaxBoundary = false
        }
        
        // 2. Discrete ticks for each percentage step to feel like a hardware dial
        let percentInt = Int(clampedPercentage * 100)
        if percentInt != lastHapticPercentage && clampedPercentage > 0.05 && clampedPercentage < 1.0 {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
            lastHapticPercentage = percentInt
        }
        #endif
    }
}


