import Cocoa
import SwiftUI

/// Custom hosting view that allows SwiftUI content to respond to clicks
/// even when the window isn't focused.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
}
