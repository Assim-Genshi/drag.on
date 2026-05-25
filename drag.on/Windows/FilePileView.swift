import Cocoa

/// Renders file thumbnails as a stacked pile of cards.
final class FilePileNSView: NSView, NSDraggingSource {

    private let store: LairStore
    private var cardViews: [FileCardNSView] = []
    private var needsReload = false
    var isReloadPending = false

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
        if let lairWindow = self.window as? LairWindow {
            lairWindow.isExternalDragActive = true
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        if let lairWindow = self.window as? LairWindow {
            lairWindow.isExternalDragActive = false
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    // MARK: - Card Management

    func reloadCards() {
        if let lairWindow = self.window as? LairWindow, lairWindow.isInternalDragActive {
            isReloadPending = true
            return
        }
        
        isReloadPending = false
        let items = Array(store.items.suffix(5))
        
        // 1. Remove obsolete cards
        cardViews.forEach { card in
            if !items.contains(where: { $0.id == card.item.id }) {
                card.removeFromSuperview()
            }
        }

        // 2. Build recycled and new card list, ordering them so newest is on top
        var newCardViews: [FileCardNSView] = []
        for item in items {
            if let existingCard = cardViews.first(where: { $0.item.id == item.id }) {
                // Moving it to the end of subviews array ensures it's drawn on top in order
                addSubview(existingCard)
                newCardViews.append(existingCard)
            } else {
                let card = FileCardNSView(item: item, store: store)
                addSubview(card)
                card.loadThumbnailAsync()
                newCardViews.append(card)
            }
        }
        cardViews = newCardViews
        needsLayout = true
    }

    override func layout() {
        super.layout()
        
        // Only reload if flagged — avoid redundant reloads on every layout pass
        if needsReload {
            needsReload = false
            reloadCards()
        }

        let itemsCount = cardViews.count
        guard itemsCount > 0 else { return }

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

        for (index, card) in cardViews.enumerated() {
            let offset = itemsCount - 1 - index

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
            if card.item.isImage {
                card.layer?.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
                card.layer?.shadowRadius = 8
                card.layer?.shadowOffset = CGSize(width: 0, height: -3)
                card.layer?.shadowOpacity = 1
            } else {
                card.layer?.shadowOpacity = 0
            }
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
