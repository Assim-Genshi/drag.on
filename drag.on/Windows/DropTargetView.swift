import Cocoa

/// Root content view of the LairWindow.
/// Previously handled drop registration but that responsibility has moved
/// to the DropOverlayView which sits at the top of the z-order.
///
/// Also installs an `.activeAlways` tracking area so the window automatically
/// becomes key when the cursor enters — this lets file drag-out sessions start
/// even when the Lair was not previously focused.
final class DropTargetView: NSView {

    private let store: LairStore

    init(store: LairStore) {
        self.store = store
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard store.items.isEmpty else { return nil }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let pasteItem = NSMenuItem(
            title: "Paste",
            action: #selector(pasteFromClipboardCommand(_:)),
            keyEquivalent: ""
        )
        pasteItem.target = self
        if let pasteIcon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) {
            pasteItem.image = pasteIcon
        }
        pasteItem.isEnabled = store.hasClipboardContent()
        menu.addItem(pasteItem)
        
        return menu
    }
    
    @objc private func pasteFromClipboardCommand(_ sender: Any) {
        store.pasteFromClipboard()
    }
}
