import Cocoa
import SwiftUI

/// A separate floating HUD panel for the image converter dialog.
/// Appears near the Lair window with its own translucent background.
class ConvertPanel: NSPanel {

    private let store: ShelfStore
    private let converter: ImageConverter

    init(store: ShelfStore, converter: ImageConverter) {
        self.store = store
        self.converter = converter

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        configurePanel()
        setupContent()
    }

    // MARK: - Configuration

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

    // MARK: - Content

    private func setupContent() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 380))
        container.autoresizingMask = [.width, .height]
        contentView = container

        // Visual Effect background — same HUD material as the Lair
        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        container.addSubview(visualEffect)

        // SwiftUI converter content
        let convertView = ConvertView(
            store: store,
            converter: converter,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hosting = NSHostingView(rootView: convertView)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        visualEffect.addSubview(hosting)
    }

    // MARK: - Show / Dismiss

    /// Show the panel centered on the screen containing the reference window.
    func show(relativeTo lairFrame: NSRect) {
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 380

        // Center on screen containing the Lair
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: lairFrame.midX, y: lairFrame.midY)) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.midY - panelHeight / 2

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)

        alphaValue = 0
        orderFrontRegardless()
        
        // Take focus immediately
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    override var canBecomeKey: Bool { true }

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
