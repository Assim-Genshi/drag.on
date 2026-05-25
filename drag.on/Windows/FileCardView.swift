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
    private weak var activeLairWindow: LairWindow?

    init(item: FileItem, store: LairStore) {
        self.item = item
        self.store = store
        // Synchronously check the cache first to avoid placeholder flash
        if let cached = ThumbnailCache.shared.cachedImage(for: item.filePath) {
            self.cachedThumbnail = cached
        } else {
            self.cachedThumbnail = item.placeholderImage()
        }
        super.init(frame: .zero)

        wantsLayer = true
        // Register as a drop destination so external drags landing on a card
        // are accepted instead of silently blocked.
        registerForDraggedTypes([.fileURL])

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
    override var mouseDownCanMoveWindow: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Once an external drag is detected, make all cards transparent so the
        // underlying pile / drop-target views handle subsequent drag events.
        if let lairWindow = window as? LairWindow, lairWindow.isExternalDragActive {
            return nil
        }
        return super.hitTest(point)
    }

    // MARK: - Drop Destination (external drag acceptance)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Reject drops that originate from our own file cards (outbound drags).
        if sender.draggingSource is FileCardNSView { return [] }

        guard sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) else { return [] }

        // Set the flag so that on subsequent hit-tests all cards become
        // transparent, letting the pile handle the rest of the drag session.
        if let lairWindow = self.window as? LairWindow {
            lairWindow.isExternalDragActive = true
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingSource is FileCardNSView { return [] }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        // Don't reset isExternalDragActive here — the drag is still in
        // progress and will be picked up by the pile or drop-target view.
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // Fallback: if the drop lands directly on this card before the drag
        // transitions to the pile, handle it by forwarding to the store.
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            if let lairWindow = self.window as? LairWindow {
                lairWindow.isExternalDragActive = false
            }
            return false
        }
        if let lairWindow = self.window as? LairWindow {
            lairWindow.cancelShakeAutoClose()
            lairWindow.isExternalDragActive = false
        }
        store.addFilesAsync(urls: urls)
        return true
    }

    // MARK: - Async Thumbnail Loading

    /// Load a high-resolution thumbnail asynchronously and update the image view.
    func loadThumbnailAsync() {
        Task { @MainActor in
            let highRes = await item.thumbnailAsync()
            // Guard against the view being removed from the hierarchy
            guard self.superview != nil else { return }
            
            if self.cachedThumbnail !== highRes {
                self.cachedThumbnail = highRes

                // Subtle cross-fade transition and animate layout updates
                if let parentPile = self.superview as? FilePileNSView {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.25
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        context.allowsImplicitAnimation = true
                        
                        self.imageView.image = highRes
                        parentPile.needsLayout = true
                    }, completionHandler: nil)
                } else {
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.15
                        context.allowsImplicitAnimation = true
                        self.imageView.image = highRes
                    }, completionHandler: nil)
                }
            } else {
                self.imageView.image = highRes
            }
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

            // Strip security scope by creating a fresh, standard NSURL from the path
            let cleanURL = NSURL(fileURLWithPath: url.path)
            let dragItem = NSDraggingItem(pasteboardWriter: cleanURL)

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
        if let lairWindow = window as? LairWindow {
            self.activeLairWindow = lairWindow
            lairWindow.registerDraggingCard(self)
        }

        // Dim the card to indicate it's being dragged — no window hiding
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 0.3
        }
        
        // Only ignore mouse events if dragging outside the window
        if let window = activeLairWindow {
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let isInside = window.contentView?.bounds.contains(windowPoint) ?? false
            window.ignoresMouseEvents = !isInside
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        movedTo screenPoint: NSPoint
    ) {
        if let window = activeLairWindow {
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
        if let window = activeLairWindow {
            window.ignoresMouseEvents = false
            window.unregisterDraggingCard(self)
            self.activeLairWindow = nil
        } else {
            window?.ignoresMouseEvents = false
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
    }

    // MARK: - Contextual Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let removeItem = NSMenuItem(
            title: LairConstants.Lair.removeFromLairActionText,
            action: #selector(removeFromLairCommand(_:)),
            keyEquivalent: ""
        )
        removeItem.target = self
        if let removeIcon = NSImage(systemSymbolName: LairConstants.Lair.removeFromLairActionIcon, accessibilityDescription: nil) {
            removeItem.image = removeIcon
        }
        removeItem.isEnabled = true
        menu.addItem(removeItem)
        
        let clearItem = NSMenuItem(
            title: LairConstants.Lair.clearActionText,
            action: #selector(clearLairCommand(_:)),
            keyEquivalent: ""
        )
        clearItem.target = self
        if let clearIcon = NSImage(systemSymbolName: LairConstants.Lair.clearActionIcon, accessibilityDescription: nil) {
            clearItem.image = clearIcon
        }
        clearItem.isEnabled = true
        menu.addItem(clearItem)
        
        return menu
    }

    @objc private func removeFromLairCommand(_ sender: Any) {
        store.removeFile(id: item.id)
    }

    @objc private func clearLairCommand(_ sender: Any) {
        store.clearAll()
    }
}
