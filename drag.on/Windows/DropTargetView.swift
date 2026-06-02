import Cocoa

/// Root content view of the LairWindow.
/// Previously handled drop registration but that responsibility has moved
/// to the DropOverlayView which sits at the top of the z-order.
///
/// Also installs an `.activeAlways` tracking area so the window automatically
/// becomes key when the cursor enters — this lets file drag-out sessions start
/// even when the Lair was not previously focused.
final class DropTargetView: NSView {

    init() {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
}
