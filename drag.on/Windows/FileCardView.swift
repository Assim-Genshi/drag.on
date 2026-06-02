import Cocoa
import os
import CoreImage

/// An NSView representing a single file thumbnail card.
/// Handles drag initiation for native file dragging.
final class FileCardNSView: NSView, NSDraggingSource {

    let item: FileItem
    private let store: LairStore
    var isNewCard = true
    private let imageView = NSImageView()
    private var dragOrigin: NSPoint?
    /// Cached thumbnail for sizing and drag previews.
    /// Initially set to a fast placeholder; replaced asynchronously with high-res.
    private(set) var cachedThumbnail: NSImage
    private weak var activeLairWindow: LairWindow?
    private var mouseDownEvent: NSEvent?

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
        
        if item.isDownloading {
            self.alphaValue = 0.5
        }
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
    override func shouldDelayWindowOrdering(for event: NSEvent) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point) != nil ? self : nil
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
        mouseDownEvent = event
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 5 else { return }

        dragOrigin = nil

        let allItems = store.items
        guard !allItems.isEmpty else { return }

        // Generate the composite stack preview image
        let compositeImage = DragPreviewGenerator.compositeStackImage(for: allItems, totalCount: allItems.count)
        let compositeSize = DragPreviewGenerator.dragImageSize(for: allItems.count)

        // All dragging items share the exact same bounds/center relative to the mouse.
        // This ensures that even if AppKit/Finder attempts to apply a custom layout/formation,
        // all items remain perfectly overlapping, maintaining the unified stack visual.
        let dragRect = NSRect(
            x: current.x - compositeSize.width / 2,
            y: current.y - compositeSize.height / 2,
            width: compositeSize.width,
            height: compositeSize.height
        )

        var dragItems: [NSDraggingItem] = []

        for (offset, fileItem) in allItems.enumerated() {
            guard let url = fileItem.resolveURL() else { continue }

            // Strip security scope by creating a fresh, standard NSURL from the path
            let cleanURL = NSURL(fileURLWithPath: url.path)
            let dragItem = NSDraggingItem(pasteboardWriter: cleanURL)

            if offset == 0 {
                // First item carries the composite stack preview
                dragItem.setDraggingFrame(dragRect, contents: compositeImage)
            } else {
                // All other items are invisible — still registered for multi-file drop
                let emptyImage = NSImage(size: NSSize(width: 1, height: 1))
                dragItem.setDraggingFrame(dragRect, contents: emptyImage)
            }
            dragItems.append(dragItem)
        }

        guard !dragItems.isEmpty else { return }
        
        let dragEvent = mouseDownEvent ?? event
        let session = beginDraggingSession(with: dragItems, event: dragEvent, source: self)
        session.draggingFormation = .none
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    override func mouseUp(with event: NSEvent) {
        dragOrigin = nil
        mouseDownEvent = nil
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
        session.draggingFormation = .none

        if let lairWindow = window as? LairWindow {
            self.activeLairWindow = lairWindow
            lairWindow.registerDraggingCard(self)
        }

        // Hide the card completely to indicate it's being dragged — no window hiding
        self.alphaValue = 0.0
        
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
        session.draggingFormation = .none

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
        
        if let pileView = self.superview as? FilePileNSView {
            pileView.triggerBounceBackAnimation(from: screenPoint)
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                self.animator().alphaValue = 1.0
            }
        }
    }

    /// Performs a high-performance, direction-aware slide back and a soft impact bounce/wiggle.
    func performBounceAnimation(offsetX: CGFloat, offsetY: CGFloat, delay: TimeInterval) {
        guard let layer = self.layer else { return }
        
        layer.removeAnimation(forKey: "bounceTranslationX")
        layer.removeAnimation(forKey: "bounceTranslationY")
        layer.removeAnimation(forKey: "bounceRotation")
        
        let currentTime = CACurrentMediaTime()
        let beginTime = currentTime + delay
        let duration: TimeInterval = 0.52
        
        // Cap the maximum initial offset to keep the visual slide within local limits
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        var finalOffsetX = offsetX
        var finalOffsetY = offsetY
        let maxDistance: CGFloat = 300.0
        if distance > maxDistance {
            finalOffsetX = (offsetX / distance) * maxDistance
            finalOffsetY = (offsetY / distance) * maxDistance
        }
        
        // Calculate a soft, capped overshoot on impact (opposite direction)
        var overshootX = -finalOffsetX * 0.12
        var overshootY = -finalOffsetY * 0.12
        let maxOvershoot: CGFloat = 10.0
        let overshootDist = sqrt(overshootX * overshootX + overshootY * overshootY)
        if overshootDist > maxOvershoot {
            overshootX = (overshootX / overshootDist) * maxOvershoot
            overshootY = (overshootY / overshootDist) * maxOvershoot
        }
        
        // Rebound offset (soft settling)
        let reboundX = -overshootX * 0.4
        let reboundY = -overshootY * 0.4
        
        // 1. Translation X Timeline
        let animX = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animX.values = [
            finalOffsetX,
            overshootX,
            reboundX,
            0
        ]
        animX.keyTimes = [0, 0.44, 0.72, 1.0] as [NSNumber]
        animX.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        animX.duration = duration
        animX.beginTime = beginTime
        animX.fillMode = .both
        animX.isAdditive = true
        
        // 2. Translation Y Timeline
        let animY = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animY.values = [
            finalOffsetY,
            overshootY,
            reboundY,
            0
        ]
        animY.keyTimes = animX.keyTimes
        animY.timingFunctions = animX.timingFunctions
        animY.duration = duration
        animY.beginTime = beginTime
        animY.fillMode = .both
        animY.isAdditive = true
        
        // 3. Soft Rotational Wiggle (only triggered on impact to simulate hitting the pile)
        let animRot = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let maxRot: Double = 0.016 * (Double.random(in: 0.7...1.3)) * (Double.random(in: 0...1) > 0.5 ? 1.0 : -1.0)
        animRot.values = [
            0,
            0,
            maxRot,
            -maxRot * 0.4,
            0
        ]
        animRot.keyTimes = [0, 0.36, 0.56, 0.8, 1.0] as [NSNumber]
        animRot.timingFunctions = animX.timingFunctions
        animRot.duration = duration
        animRot.beginTime = beginTime
        animRot.fillMode = .both
        animRot.isAdditive = true
        
        layer.add(animX, forKey: "bounceTranslationX")
        layer.add(animY, forKey: "bounceTranslationY")
        layer.add(animRot, forKey: "bounceRotation")
    }

    /// Animates the card scaling down in place, fading out, and playing a cloud animation overlay before removal.
    func performClearAnimation(completion: @escaping () -> Void) {
        wantsLayer = true
        guard let layer = self.layer else {
            completion()
            return
        }
        
        layer.removeAnimation(forKey: "bounceTranslationX")
        layer.removeAnimation(forKey: "bounceTranslationY")
        layer.removeAnimation(forKey: "bounceRotation")
        
        // Remove filters (no blur) and disable rasterization to allow dynamic content frame updates
        layer.filters = nil
        layer.shouldRasterize = false
        
        // Load the 5 cloud animation frames from assets
        var frames: [CGImage] = []
        for i in 1...5 {
            if let image = NSImage(named: "cloud animation frame \(i)"),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                frames.append(cgImage)
            }
        }
        
        // Explicitly set anchor point to the center to guarantee scaling occurs around the center
        let cardFrame = self.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
        
        // Create a square overlay view centered on the card for the cloud puff
        let side = min(self.bounds.width, self.bounds.height)
        let overlayView = NSImageView(frame: NSRect(
            x: (self.bounds.width - side) / 2,
            y: (self.bounds.height - side) / 2,
            width: side,
            height: side
        ))
        overlayView.imageScaling = .scaleProportionallyUpOrDown
        overlayView.wantsLayer = true
        self.addSubview(overlayView)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            // Fade out the card
            self.animator().alphaValue = 0.0
            
            // Scale down in place (preserving stable rotation)
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 1.0
            scaleAnim.toValue = 0.6
            scaleAnim.duration = 0.25
            scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scaleAnim.fillMode = .forwards
            scaleAnim.isRemovedOnCompletion = false
            layer.add(scaleAnim, forKey: "clearScale")
            
            // Play the 5-frame cloud animation on the overlay layer
            if !frames.isEmpty {
                let frameAnim = CAKeyframeAnimation(keyPath: "contents")
                frameAnim.values = frames
                frameAnim.duration = 0.25
                frameAnim.calculationMode = .discrete
                frameAnim.fillMode = .forwards
                frameAnim.isRemovedOnCompletion = false
                overlayView.layer?.add(frameAnim, forKey: "cloudAnimation")
            }
            
        }, completionHandler: {
            overlayView.removeFromSuperview()
            completion()
        })
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
