import SwiftUI

/// A reusable circular icon button for Drag.on controls.
struct LairCircleButton: View {
    let systemName: String
    var action: (() -> Void)? = nil
    var isLightBackground: Bool = false

    @State private var isHovering = false

    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    buttonContent
                }
                .buttonStyle(.plain)
            } else {
                buttonContent
            }
        }
        .scaleEffect(isHovering ? 1.15 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(Text(systemName))
    }

    private var buttonContent: some View {
        ZStack {
            Circle()
                .fill(Color("Secondary-surfece").opacity(LairConstants.Lair.buttonBackgroundOpacity))
                .frame(width: 30, height: 30)

            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color("content-100"))
        }
        .overlay(
            Circle()
                .stroke(Color("border-color").opacity(LairConstants.Lair.buttonBorderOpacity), lineWidth: 1.0)
        )
    }
}
