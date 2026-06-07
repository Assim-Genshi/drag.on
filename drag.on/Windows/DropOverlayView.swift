import Cocoa

/// Invisible overlay that serves as the **sole drop target** for the entire Lair window.
///
/// Sits at the top of the z-order above all cards and SwiftUI content.
/// Completely transparent to clicks/interactions by default — only intercepts
/// drag events during active external drag sessions.
///
/// Features a radial gradient "glow blob" that tracks the cursor position
/// during drag hover for visual feedback.
final class DropOverlayView: NSView {

    private let store: LairStore

    /// The CAGradientLayer used for the radial glow blob effect during drags.
    private let glowLayer = CAGradientLayer()

    /// Tracks whether we are actively receiving an external drag.
    private var isReceivingDrag = false

    init(store: LairStore) {
        self.store = store
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        registerForDraggedTypes([.fileURL, .URL, .string])
        setupGlowLayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Glow Blob Layer

    private func setupGlowLayer() {
        glowLayer.type = .radial
        glowLayer.colors = [
            NSColor.white.withAlphaComponent(0.45).cgColor,
            NSColor.white.withAlphaComponent(0.15).cgColor,
            NSColor.clear.cgColor
        ]
        glowLayer.locations = [0.0, 0.4, 1.0]
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        glowLayer.compositingFilter = "overlayBlendMode"
        glowLayer.opacity = 0
        glowLayer.frame = CGRect(x: 0, y: 0, width: 260, height: 260)
        glowLayer.cornerRadius = 130
        layer?.addSublayer(glowLayer)
    }

    private func updateGlowPosition(at windowPoint: NSPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let localPoint = convert(windowPoint, from: superview)
        let glowSize: CGFloat = 260
        glowLayer.frame = CGRect(
            x: localPoint.x - glowSize / 2,
            y: localPoint.y - glowSize / 2,
            width: glowSize,
            height: glowSize
        )
        CATransaction.commit()
    }

    private func showGlow() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        glowLayer.opacity = 1
        CATransaction.commit()
    }

    private func hideGlow() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        glowLayer.opacity = 0
        CATransaction.commit()
    }

    // MARK: - Hit Test

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept hits during active external drags.
        // Otherwise, the overlay is completely transparent to all interactions.
        if isReceivingDrag {
            return self
        }
        return nil
    }

    // MARK: - Drag Destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Reject drags originating from within the lair (outbound card drags)
        if sender.draggingSource is FileCardNSView { return [] }
        if sender.draggingSource is DragSourceNSView { return [] }

        // Belt-and-suspenders: also check the window-level internal drag flag
        if let lairWindow = window as? LairWindow, lairWindow.isInternalDragActive {
            return []
        }

        // Validate pasteboard content
        let pb = sender.draggingPasteboard
        let canReadFileURL = pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        let canReadURL = pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: false])
        let canReadString = pb.canReadObject(forClasses: [NSString.self], options: nil)

        guard canReadFileURL || canReadURL || canReadString else {
            return []
        }

        // Apply visual stack formation when dragging multiple files over the lair
        sender.draggingFormation = .stack

        // Activate external drag state on the window
        isReceivingDrag = true
        if let lairWindow = window as? LairWindow {
            lairWindow.isExternalDragActive = true
        }

        // Show the radial glow blob at the cursor position
        let windowPoint = convert(sender.draggingLocation, from: nil)
        updateGlowPosition(at: windowPoint)
        showGlow()

        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Continue rejecting internal drags as a safety guard
        if sender.draggingSource is FileCardNSView { return [] }
        if sender.draggingSource is DragSourceNSView { return [] }

        // Track the cursor with the glow blob
        let windowPoint = convert(sender.draggingLocation, from: nil)
        updateGlowPosition(at: windowPoint)

        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isReceivingDrag = false
        hideGlow()
        if let lairWindow = window as? LairWindow {
            lairWindow.isExternalDragActive = false
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isReceivingDrag = false
        hideGlow()

        let pb = sender.draggingPasteboard
        let windowPoint = sender.draggingLocation

        // 1. Try local file URLs first
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            if let lairWindow = window as? LairWindow {
                lairWindow.lastDropLocation = windowPoint
                lairWindow.cancelShakeAutoClose()
                lairWindow.isExternalDragActive = false
            }
            store.addFilesAsync(urls: urls)
            return true
        }

        // 2. Try web URLs (http/https)
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: false]) as? [URL], !urls.isEmpty {
            let webURLs = urls.filter { $0.scheme == "http" || $0.scheme == "https" }
            if !webURLs.isEmpty {
                if let lairWindow = window as? LairWindow {
                    lairWindow.lastDropLocation = windowPoint
                    lairWindow.cancelShakeAutoClose()
                    lairWindow.isExternalDragActive = false
                }
                for url in webURLs {
                    store.addWebDrop(url: url)
                }
                return true
            }
        }

        // 3. Try strings parsed as URLs (e.g. Pinterest drags as plain string)
        if let strings = pb.readObjects(forClasses: [NSString.self], options: nil) as? [String] {
            let stringURLs = strings.compactMap { URL(string: $0) }.filter { $0.scheme == "http" || $0.scheme == "https" }
            if !stringURLs.isEmpty {
                if let lairWindow = window as? LairWindow {
                    lairWindow.lastDropLocation = windowPoint
                    lairWindow.cancelShakeAutoClose()
                    lairWindow.isExternalDragActive = false
                }
                for url in stringURLs {
                    store.addWebDrop(url: url)
                }
                return true
            }
        }

        // No valid content found
        if let lairWindow = window as? LairWindow {
            lairWindow.isExternalDragActive = false
        }
        return false
    }
}
