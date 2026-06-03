import SwiftUI

/// A reusable action button used in the Lair Manager batch actions bar.
struct ManagementButton<Icon: View>: View {
    let icon: Icon
    let text: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    private var content100: Color {
        Color("content-100")
    }

    private var borderColor: Color {
        Color("border-color")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                icon
                Text(text)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(isHovering ? color : content100.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color("Secondary-surfece").opacity(LairConstants.Lair.buttonBackgroundOpacity))
            )
            .overlay(
                Capsule()
                    .stroke(borderColor.opacity(LairConstants.Lair.buttonBorderOpacity), lineWidth: 1.0)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.15 : 1.0)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = h
            }
        }
    }
}
