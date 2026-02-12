import Cocoa
import SwiftUI

/// A floating, translucent panel that acts as the Drag.on Lair drop zone.
class ShelfWindow: NSPanel {

    private let store: ShelfStore
    private var hostingView: FirstMouseHostingView<ShelfView>?
    private var initialDragWindowOrigin: NSPoint?

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

    private func setupContent() {
        let dropView = DropTargetView(store: store)
        dropView.frame = NSRect(x: 0, y: 0, width: 200, height: 200)
        dropView.autoresizingMask = [.width, .height]
        contentView = dropView

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

        let shelfView = ShelfView(
            store: store,
            onClose: { [weak self] in self?.hide() },
            onWindowDrag: { [weak self] event in
                self?.handleWindowDrag(event)
            }
        )

        let hosting = FirstMouseHostingView(rootView: shelfView)
        hosting.frame = dropView.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear

        visualEffect.addSubview(hosting)
        self.hostingView = hosting
    }

    private func handleWindowDrag(_ event: WindowDragEvent) {
        switch event {
        case .began:
            initialDragWindowOrigin = frame.origin
            makeKey()
        case .changed(let translation):
            guard let initialOrigin = initialDragWindowOrigin else { return }
            setFrameOrigin(NSPoint(x: initialOrigin.x + translation.width, y: initialOrigin.y - translation.height))
        case .ended:
            initialDragWindowOrigin = nil
        }
    }

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

    private func screenContaining(point: NSPoint) -> NSScreen? {
        for screen in NSScreen.screens where screen.frame.contains(point) {
            return screen
        }
        return nil
    }

    override var canBecomeKey: Bool { true }
}

final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

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
        .copy
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
