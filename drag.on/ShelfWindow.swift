import Cocoa
import SwiftUI

/// A floating, translucent panel that acts as the Drag.on Lair drop zone.
class ShelfWindow: NSPanel {

    private let store: ShelfStore
    private var hostingView: NSHostingView<ShelfView>?

    init(store: ShelfStore) {
        self.store = store

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        configurePanel()
        setupContent()
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
        dropView.frame = NSRect(x: 0, y: 0, width: 200, height: 200)
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

        // SwiftUI hosting view
        let shelfView = ShelfView(store: store, onClose: { [weak self] in
            self?.hide()
        })
        let hosting = NSHostingView(rootView: shelfView)
        hosting.frame = dropView.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear

        visualEffect.addSubview(hosting)
        self.hostingView = hosting

        // Drag handle — small pill area at top center only, doesn't block the close button
        let pillWidth: CGFloat = 60
        let handleView = WindowDragHandleView(frame: .zero)
        handleView.frame = NSRect(
            x: (200 - pillWidth) / 2,
            y: 200 - 24,  // Top 24pt, centered (AppKit y=0 is bottom)
            width: pillWidth,
            height: 30
        )
        handleView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
        dropView.addSubview(handleView)
    }

    // MARK: - Show / Hide

    func show(near point: NSPoint) {
        let screen = screenContaining(point: point) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        let panelSize: CGFloat = 200

        var x = point.x - panelSize / 2
        var y = point.y - panelSize - 20

        x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - panelSize - 10))
        y = max(screenFrame.minY + 10, min(y, screenFrame.maxY - panelSize - 10))

        setFrame(NSRect(x: x, y: y, width: panelSize, height: panelSize), display: true)

        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    func toggle(near point: NSPoint) {
        if isVisible {
            hide()
        } else {
            show(near: point)
        }
    }

    // MARK: - Multi-Monitor

    private func screenContaining(point: NSPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return nil
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - Window Drag Handle View

/// Small transparent view positioned at the top center (over the pill indicator).
/// Only this area lets the user drag the window around.
class WindowDragHandleView: NSView {

    private var initialMouseLocation: NSPoint?
    private var initialWindowOrigin: NSPoint?

    // Accept mouse events even when the window is not focused
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        // Make the window key so it can receive events properly
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
