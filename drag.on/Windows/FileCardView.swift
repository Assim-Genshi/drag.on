import Cocoa

/// An NSView representing a single file thumbnail card.
/// Handles drag initiation for native file dragging.
final class FileCardNSView: NSView, NSDraggingSource {

    let item: FileItem
    private let store: LairStore
    private let imageView = NSImageView()
    private var dragOrigin: NSPoint?
    /// Cached thumbnail for sizing and drag previews.
    /// Initially set to a fast placeholder; replaced asynchronously with high-res.
    private(set) var cachedThumbnail: NSImage

    init(item: FileItem, store: LairStore) {
        self.item = item
        self.store = store
        // Use a fast system icon placeholder — no disk I/O or image decoding
        self.cachedThumbnail = item.placeholderImage()
        super.init(frame: .zero)

        wantsLayer = true
        if item.isImage {
            layer?.cornerRadius = 10
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
            layer?.borderWidth = 0.5
            layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor
        } else {
            layer?.cornerRadius = 0
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderWidth = 0
            layer?.borderColor = NSColor.clear.cgColor
        }

        imageView.image = cachedThumbnail
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func layout() {
        super.layout()
        if item.isImage {
            let inset: CGFloat = 5
            imageView.frame = bounds.insetBy(dx: inset, dy: inset)
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 6
            imageView.layer?.masksToBounds = true
            imageView.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            imageView.frame = bounds
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 0
            imageView.layer?.masksToBounds = false
            imageView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Async Thumbnail Loading

    /// Load a high-resolution thumbnail asynchronously and update the image view.
    func loadThumbnailAsync() {
        Task { @MainActor in
            let highRes = await item.thumbnailAsync()
            // Guard against the view being removed from the hierarchy
            guard self.superview != nil else { return }
            self.cachedThumbnail = highRes

            // Subtle cross-fade transition
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                self.imageView.image = highRes
            }, completionHandler: nil)
        }
    }

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

            // Use NSURL directly as NSPasteboardWriting — native UTI handling
            let dragItem = NSDraggingItem(pasteboardWriter: url as NSURL)

            let stackOffset = CGFloat(offset) * 4
            let dragRect = NSRect(
                x: current.x - imageSize.width / 2 + stackOffset,
                y: current.y - imageSize.height / 2 - stackOffset,
                width: imageSize.width,
                height: imageSize.height
            )
            // Use the cached thumbnail for the drag preview (no re-decode)
            dragItem.setDraggingFrame(dragRect, contents: cachedThumbnail)
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
        return .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint
    ) {
        // Dim the card to indicate it's being dragged — no window hiding
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 0.3
        }
        // Only ignore mouse events if dragging outside the window
        if let window = self.window {
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let isInside = window.contentView?.bounds.contains(windowPoint) ?? false
            window.ignoresMouseEvents = !isInside
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        movedTo screenPoint: NSPoint
    ) {
        if let window = self.window {
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let isInside = window.contentView?.bounds.contains(windowPoint) ?? false
            if window.ignoresMouseEvents != !isInside {
                window.ignoresMouseEvents = !isInside
            }
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        // Restore the card and window interactivity
        window?.ignoresMouseEvents = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
    }
}
