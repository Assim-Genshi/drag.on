import Cocoa

/// Renders file thumbnails as a stacked pile of cards.
final class FilePileNSView: NSView, NSDraggingSource {

    private let store: LairStore
    private var cardViews: [FileCardNSView] = []
    private var needsReload = false

    init(store: LairStore) {
        self.store = store
        super.init(frame: .zero)
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
        reloadCards()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Drop Destination (pass-through)

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) else {
            return []
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            return false
        }
        if let lairWindow = self.window as? LairWindow {
            lairWindow.cancelShakeAutoClose()
        }
        store.addFilesAsync(urls: urls)
        return true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Card Management

    func reloadCards() {
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()

        let items = Array(store.items.suffix(5))
        guard !items.isEmpty else { return }

        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        let isConvertShown = store.hasImages && !isCompact
        
        let maxDimension: CGFloat
        if isCompact {
            maxDimension = LairConstants.Lair.fileItemCompactDimension
        } else if isConvertShown {
            maxDimension = LairConstants.Lair.fileItemLargeDimension
        } else {
            maxDimension = LairConstants.Lair.fileItemStandardDimension
        }
        
        let padding: CGFloat = 5
        let rotations: [Double] = [0, -5, 4, -3, 6]

        for (index, item) in items.enumerated() {
            let card = FileCardNSView(item: item, store: store)
            let offset = items.count - 1 - index

            let thumb = card.cachedThumbnail
            let thumbSize = thumb.size
            let aspect = thumbSize.width / max(thumbSize.height, 1)

            let cardW: CGFloat
            let cardH: CGFloat
            if aspect >= 1 {
                cardW = maxDimension
                cardH = maxDimension / aspect
            } else {
                cardW = maxDimension * aspect
                cardH = maxDimension
            }

            let totalW = cardW + padding * 2
            let totalH = cardH + padding * 2

            let x = (bounds.width - totalW) / 2
            let y = (bounds.height - totalH) / 2 - CGFloat(offset) * 2

            card.frame = NSRect(x: x, y: y, width: totalW, height: totalH)
            card.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]

            card.wantsLayer = true
            let rot = rotations[offset % rotations.count]
            card.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            card.layer?.position = CGPoint(x: x + totalW / 2, y: y + totalH / 2)
            card.frameCenterRotation = rot

            card.shadow = NSShadow()
            if item.isImage {
                card.layer?.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
                card.layer?.shadowRadius = 8
                card.layer?.shadowOffset = CGSize(width: 0, height: -3)
                card.layer?.shadowOpacity = 1
            } else {
                card.layer?.shadowOpacity = 0
            }

            addSubview(card)
            cardViews.append(card)

            // Fire async thumbnail loading — non-blocking
            card.loadThumbnailAsync()
        }
    }

    override func layout() {
        super.layout()
        // Only reload if flagged — avoid redundant reloads on every layout pass
        if needsReload {
            needsReload = false
            reloadCards()
        }
    }

    /// Mark that cards need reloading on next layout pass.
    func setNeedsReload() {
        needsReload = true
        needsLayout = true
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return .copy
    }
}
