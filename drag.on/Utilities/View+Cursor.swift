import SwiftUI
import Cocoa

extension View {
    /// Applies a standard pointing hand cursor on hover for macOS 14+ systems.
    func pointerCursor() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
