import Cocoa

/// An NSView representing a single file thumbnail card.
/// Handles drag initiation for native file dragging.
final class FileCardNSView: NSView, NSDraggingSource {

    let item: FileItem
    private let store: LairStore
    private let imageView = NSImageView()
    private var dragOrigin: NSPoint?
    /// Cached thumbnail for sizing (generated once).
    let cachedThumbnail: NSImage

    init(item: FileItem, store: LairStore) {
        self.item = item
        self.store = store
        self.cachedThumbnail = item.thumbnail()
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor

        imageView.image = cachedThumbnail
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 5
        imageView.frame = bounds.insetBy(dx: inset, dy: inset)
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Mouse Drag → File Drag Session

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
        window?.makeKey()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 5 else { return }

        dragOrigin = nil

        var dragItems: [NSDraggingItem] = []
        let imageSize = NSSize(width: 80, height: 80)

        for (offset, fileItem) in store.items.enumerated() {
            guard let url = fileItem.resolveURL() else { continue }

            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)

            let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

            let stackOffset = CGFloat(offset) * 4
            let dragRect = NSRect(
                x: current.x - imageSize.width / 2 + stackOffset,
                y: current.y - imageSize.height / 2 - stackOffset,
                width: imageSize.width,
                height: imageSize.height
            )
            dragItem.setDraggingFrame(dragRect, contents: fileItem.thumbnail())
            dragItems.append(dragItem)
        }

        guard !dragItems.isEmpty else { return }
        beginDraggingSession(with: dragItems, event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return context == .outsideApplication ? .copy : .move
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if operation != [] {
            store.clearAll()
        }
    }
}
