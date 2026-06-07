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
        reloadCards()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if cardViews.isEmpty {
            return nil
        }
        return super.hitTest(point)
    }

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
                card.performClearAnimation {
                    card.removeFromSuperview()
                }
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

        var dropLocation: NSPoint? = nil
        if let lairWindow = self.window as? LairWindow, let lastDrop = lairWindow.lastDropLocation {
            dropLocation = lastDrop
            lairWindow.lastDropLocation = nil
        }
        let localDropPoint = dropLocation.map { self.convert($0, from: nil) }

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

        CATransaction.begin()
        CATransaction.setDisableActions(true)

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

            // 1. MUST reset rotation to 0 before setting frame to prevent AppKit geometry jumps
            card.frameCenterRotation = 0.0

            card.frame = NSRect(x: x, y: y, width: totalW, height: totalH)
            card.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]

            card.wantsLayer = true
            
            // 2. Set anchor point to center to allow proper scaling and rotations
            card.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            card.layer?.position = CGPoint(x: x + totalW / 2, y: y + totalH / 2)
            
            let rot = card.item.stableRotation
            
            if card.isNewCard {
                card.isNewCard = false
                
                // Set the final rotation so scale animation builds upon it
                card.frameCenterRotation = rot
                
                let delay = Double(itemsCount - 1 - index) * 0.035
                let currentTime = CACurrentMediaTime()
                let beginTime = currentTime + delay
                
                // 1. Opacity Animation
                let opacityAnimation = CABasicAnimation(keyPath: "opacity")
                opacityAnimation.fromValue = 0.0
                opacityAnimation.toValue = 1.0
                opacityAnimation.duration = 0.25
                opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                opacityAnimation.beginTime = beginTime
                opacityAnimation.fillMode = .both
                
                // 2. Scale Animation
                let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
                scaleAnimation.fromValue = 1.15
                scaleAnimation.toValue = 1.0
                scaleAnimation.duration = 0.3
                scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scaleAnimation.beginTime = beginTime
                scaleAnimation.fillMode = .both
                
                card.alphaValue = 1.0
                card.wantsLayer = true
                card.layer?.opacity = 1.0
                
                card.layer?.add(opacityAnimation, forKey: "dropAlphaAnimation")
                card.layer?.add(scaleAnimation, forKey: "dropScaleAnimation")
                
                // 3. Bounce/Slide Animation
                if let dropPoint = localDropPoint {
                    let cardCenter = CGPoint(x: x + totalW / 2, y: y + totalH / 2)
                    let offsetX = dropPoint.x - cardCenter.x
                    let offsetY = dropPoint.y - cardCenter.y
                    card.performBounceAnimation(offsetX: offsetX, offsetY: offsetY, delay: delay)
                }
            } else {
                card.frameCenterRotation = rot
            }

            card.shadow = NSShadow()
            if card.item.isImage {
                card.layer?.shadowColor = NSColor.black.withAlphaComponent(0.18).cgColor
                card.layer?.shadowRadius = 4
                card.layer?.shadowOffset = CGSize(width: 0, height: -1.5)
                card.layer?.shadowOpacity = 1
            } else {
                card.layer?.shadowOpacity = 0
            }
        }

        CATransaction.commit()
    }

    /// Mark that cards need reloading on next layout pass.
    func setNeedsReload() {
        needsReload = true
        needsLayout = true
    }

    /// Triggers a cascading physical bounce and slide-back animation on all individual cards
    /// from the coordinates where the drag was released.
    func triggerBounceBackAnimation(from screenPoint: NSPoint) {
        guard let window = self.window else { return }
        
        // Convert screen drop point to FilePileNSView coordinates
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let localDropPoint = self.convert(windowPoint, from: nil)
        
        // Apply cascading bounce animations to the stack items
        for (index, card) in cardViews.enumerated() {
            // Very fast fade-in to blend smoothly with the physical bounce
            if card.alphaValue < 1.0 {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.08
                    card.animator().alphaValue = 1.0
                }
            }
            
            // Calculate the card's resting center
            let cardCenter = CGPoint(x: card.frame.midX, y: card.frame.midY)
            
            // Vector from card center to the drop point
            let startOffsetX = localDropPoint.x - cardCenter.x
            let startOffsetY = localDropPoint.y - cardCenter.y
            
            // Cascading wave delay (topmost cards react slightly faster)
            let delay = Double(index) * 0.035
            
            card.performBounceAnimation(offsetX: startOffsetX, offsetY: startOffsetY, delay: delay)
        }
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return .copy
    }
}
