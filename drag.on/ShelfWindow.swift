import Cocoa
import SwiftUI

/// A floating, translucent panel that acts as the Drag.on Lair drop zone.
class ShelfWindow: NSPanel {

    private let store: ShelfStore
    private let converter: ImageConverter
    private var hostingView: FirstMouseHostingView<ShelfView>?
    private var filePileView: FilePileNSView?
    private var convertPanel: ConvertPanel?

    init(store: ShelfStore, converter: ImageConverter) {
        self.store = store
        self.converter = converter

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 320),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        configurePanel()
        setupContent()
        observeStoreChanges()
    }

    // MARK: - Panel Configuration

    private func configurePanel() {
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow
    }

    // MARK: - Content Setup

    private func setupContent() {
        // Root content: drop target
        let dropView = DropTargetView(store: store)
        dropView.frame = NSRect(x: 0, y: 0, width: 260, height: 320)
        dropView.autoresizingMask = [.width, .height]
        contentView = dropView

        // Visual Effect background
        let visualEffect = NSVisualEffectView(frame: dropView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 26
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        dropView.addSubview(visualEffect)

        // AppKit file pile view — sits between visual effect and SwiftUI overlay
        let pile = FilePileNSView(store: store)
        pile.frame = NSRect(x: 12, y: 60, width: 236, height: 200) // Center area inside dashed container
        pile.autoresizingMask = [.width, .height]
        visualEffect.addSubview(pile)
        self.filePileView = pile

        // SwiftUI hosting view (overlay: buttons, labels, empty state)
        let shelfView = ShelfView(store: store, onClose: { [weak self] in
            self?.hide()
        }, onConvert: { [weak self] in
            self?.showConvertPanel()
        })
        let hosting = FirstMouseHostingView(rootView: shelfView)
        hosting.frame = dropView.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.enableDropForwarding(store: store) // pointer-events: none for drops

        visualEffect.addSubview(hosting)
        self.hostingView = hosting

        // Drag handle — small pill area at top center
        let pillWidth: CGFloat = 60
        let handleView = WindowDragHandleView(frame: .zero)
        handleView.frame = NSRect(
            x: (260 - pillWidth) / 2,
            y: 320 - 24,
            width: pillWidth,
            height: 30
        )
        handleView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        dropView.addSubview(handleView)
    }

    // MARK: - Observe store changes to refresh pile

    private func observeStoreChanges() {
        // Use Combine to observe store changes
        store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.filePileView?.reloadCards()
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Show / Hide

    func show(near point: NSPoint) {
        let screen = screenContaining(point: point) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        let panelWidth: CGFloat = 260
        let panelHeight: CGFloat = 320

        var x = point.x - panelWidth / 2
        var y = point.y - panelHeight - 20

        x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - panelWidth - 10))
        y = max(screenFrame.minY + 10, min(y, screenFrame.maxY - panelHeight - 10))

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)

        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func hide() {
        convertPanel?.dismiss()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    // MARK: - Convert Panel

    func showConvertPanel() {
        if convertPanel == nil {
            convertPanel = ConvertPanel(store: store, converter: converter)
        }
        convertPanel?.show(relativeTo: self.frame)
    }

    func toggle(near point: NSPoint) {
        if isVisible { hide() } else { show(near: point) }
    }

    // MARK: - Multi-Monitor

    private func screenContaining(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    override var canBecomeKey: Bool { true }

    // Force activation on mouse events so SwiftUI buttons respond
    // without the app needing to be focused first
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        default:
            break
        }
        super.sendEvent(event)
    }
}



// MARK: - NSHostingView subclass that accepts first mouse

/// Custom hosting view that allows SwiftUI content to respond to clicks
/// even when the window isn't focused. Also forwards file drops to the store
/// so the SwiftUI overlay doesn't eat drag-and-drop events (pointer-events: none).
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    private weak var dropStore: ShelfStore?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Register this view as a drop target that forwards to the store.
    func enableDropForwarding(store: ShelfStore) {
        self.dropStore = store
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) else { return [] }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else { return false }
        dropStore?.addFiles(urls: urls)
        return true
    }
}

// MARK: - Combine import

import Combine

// MARK: - File Pile NSView (AppKit-based for proper drag-out)

/// Renders file thumbnails as a stacked pile. Each card is an NSImageView
/// that can be individually dragged out as a real file.
class FilePileNSView: NSView, NSDraggingSource {

    private let store: ShelfStore
    private var cardViews: [FileCardNSView] = []

    init(store: ShelfStore) {
        self.store = store
        super.init(frame: .zero)
        wantsLayer = true
        // Register for incoming file drops so cards don't block the drop target
        registerForDraggedTypes([.fileURL])
        reloadCards()
    }

    // MARK: - Drop destination (pass-through to store)

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
        store.addFiles(urls: urls)
        return true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // Accept mouse events without window focus
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func reloadCards() {
        // Remove old cards
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()

        let items = Array(store.items.suffix(5)) // Show last 5
        guard !items.isEmpty else { return }

        let maxDimension: CGFloat = 100
        let padding: CGFloat = 5
        let rotations: [Double] = [0, -5, 4, -3, 6]

        for (index, item) in items.enumerated() {
            let card = FileCardNSView(item: item, store: store)
            let offset = items.count - 1 - index // Back cards get higher offset

            // Compute card size from thumbnail aspect ratio
            let thumb = card.cachedThumbnail
            let thumbSize = thumb.size
            let aspect = thumbSize.width / max(thumbSize.height, 1)

            let cardW: CGFloat
            let cardH: CGFloat
            if aspect >= 1 {
                // Landscape or square
                cardW = maxDimension
                cardH = maxDimension / aspect
            } else {
                // Portrait
                cardW = maxDimension * aspect
                cardH = maxDimension
            }

            let totalW = cardW + padding * 2
            let totalH = cardH + padding * 2

            // Center card in this view
            let x = (bounds.width - totalW) / 2
            let y = (bounds.height - totalH) / 2 - CGFloat(offset) * 2

            card.frame = NSRect(x: x, y: y, width: totalW, height: totalH)
            card.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]

            // Apply rotation
            card.wantsLayer = true
            let rot = rotations[offset % rotations.count]
            card.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            card.layer?.position = CGPoint(x: x + totalW / 2, y: y + totalH / 2)
            card.frameCenterRotation = rot

            // Shadow — refined depth
            card.shadow = NSShadow()
            card.layer?.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
            card.layer?.shadowRadius = 8
            card.layer?.shadowOffset = CGSize(width: 0, height: -3)
            card.layer?.shadowOpacity = 1

            addSubview(card)
            cardViews.append(card)
        }
    }

    override func layout() {
        super.layout()
        reloadCards()
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return context == .outsideApplication ? .copy : .move
    }
}

// MARK: - Individual file card view

/// An NSView representing a single file thumbnail card.
/// Handles its own drag initiation for proper native file dragging.
class FileCardNSView: NSView, NSDraggingSource {

    let item: FileItem
    private let store: ShelfStore
    private let imageView = NSImageView()
    private var dragOrigin: NSPoint?
    /// Cached thumbnail so we only generate it once (used by FilePileNSView for sizing)
    let cachedThumbnail: NSImage

    init(item: FileItem, store: ShelfStore) {
        self.item = item
        self.store = store
        self.cachedThumbnail = item.thumbnail()
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.white.withAlphaComponent(0.6).cgColor

        // Thumbnail image
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

    // Accept clicks without window focus
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Mouse drag → file drag session

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
        // Make window key for responsive interaction
        window?.makeKey()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        let distance = sqrt(dx * dx + dy * dy)

        // Only start drag after a minimum movement (5pt)
        guard distance > 5 else { return }

        // Clear origin so we don't start multiple sessions
        dragOrigin = nil

        // Build drag items for ALL files in the store
        var dragItems: [NSDraggingItem] = []
        let imageSize = NSSize(width: 80, height: 80)

        for (offset, fileItem) in store.items.enumerated() {
            guard let url = fileItem.resolveURL() else { continue }

            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)

            let dragItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

            // Stack drag images with a slight offset so they look like a pile
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

        // Begin native drag session with all items
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
        // .copy for outside (dropping into Finder/other apps)
        // .move for inside (reordering within the app)
        return context == .outsideApplication ? .copy : .move
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        // If the drag completed successfully, clear all items from the lair
        if operation != [] {
            store.clearAll()
        }
    }
}

// MARK: - Window Drag Handle View

class WindowDragHandleView: NSView {

    private var initialMouseLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let initialMouse = initialMouseLocation,
              let initialOrigin = initialWindowOrigin else { return }

        let current = NSEvent.mouseLocation
        let dx = current.x - initialMouse.x
        let dy = current.y - initialMouse.y

        window?.setFrameOrigin(NSPoint(x: initialOrigin.x + dx, y: initialOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        initialMouseLocation = nil
        initialWindowOrigin = nil
    }

    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) { /* invisible */ }
}

// MARK: - Drop Target View

class DropTargetView: NSView {

    private let store: ShelfStore

    init(store: ShelfStore) {
        self.store = store
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // Accept drops without window focus
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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

        store.addFiles(urls: urls)
        return true
    }
}
