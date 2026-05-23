import SwiftUI

/// A reusable circular icon button for Drag.on controls.
struct LairCircleButton: View {
    let systemName: String
    let action: () -> Void
    var isLightBackground: Bool = false

    @State private var isHovering = false

    // MARK: - Dynamic Styling

    private var baseOpacity: Double {
        isLightBackground ? 0.06 : 0.15
    }

    private var hoverOpacity: Double {
        isLightBackground ? 0.12 : 0.25
    }

    private var iconColor: Color {
        if isLightBackground {
            return Color.black.opacity(isHovering ? 0.85 : 0.5)
        } else {
            return Color.white.opacity(isHovering ? 0.95 : 0.7)
        }
    }

    private var strokeColor: Color {
        if isLightBackground {
            return Color.black.opacity(isHovering ? 0.15 : 0.08)
        } else {
            return Color.white.opacity(isHovering ? 0.25 : 0.12)
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isLightBackground
                            ? Color.black.opacity(isHovering ? hoverOpacity : baseOpacity)
                            : Color.white.opacity(isHovering ? hoverOpacity : baseOpacity)
                    )
                    .frame(width: 30, height: 30)

                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(iconColor)
            }
        }
        .buttonStyle(.plain)
        .overlay(
            Circle()
                .stroke(strokeColor, lineWidth: 0.5)
        )
        .scaleEffect(isHovering ? 1.15 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(Text(systemName))
    }
}
