import Cocoa
import SwiftUI
import Combine

/// A floating, translucent panel that acts as the Drag.on Lair drop zone.
final class LairWindow: NSPanel {

    private let store: LairStore
    private let converter: ImageConverter
    private var hostingView: FirstMouseHostingView<LairView>?
    private var filePileView: FilePileNSView?
    private var convertPanel: ConvertPanel?
    private var cancellables = Set<AnyCancellable>()

    init(store: LairStore, converter: ImageConverter) {
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
        let dropView = DropTargetView(store: store)
        dropView.frame = NSRect(x: 0, y: 0, width: 260, height: 320)
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

        let pile = FilePileNSView(store: store)
        pile.frame = NSRect(x: 12, y: 60, width: 236, height: 200)
        pile.autoresizingMask = [.width, .height]
        visualEffect.addSubview(pile)
        self.filePileView = pile

        let lairView = LairView(store: store, onClose: { [weak self] in
            self?.hide()
        }, onConvert: { [weak self] in
            self?.showConvertPanel()
        })
        let hosting = FirstMouseHostingView(rootView: lairView)
        hosting.frame = dropView.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.enableDropForwarding(store: store)
        visualEffect.addSubview(hosting)
        self.hostingView = hosting

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

    // MARK: - Store Observation

    private func observeStoreChanges() {
        // Use withObservationTracking for @Observable store
        withObservationTracking {
            _ = store.items
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.filePileView?.reloadCards()
                self?.observeStoreChanges()
            }
        }
    }

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

    func toggle(near point: NSPoint) {
        if isVisible { hide() } else { show(near: point) }
    }

    // MARK: - Convert Panel

    func showConvertPanel() {
        if convertPanel == nil {
            convertPanel = ConvertPanel(store: store, converter: converter)
        }
        convertPanel?.show(relativeTo: self.frame)
    }

    // MARK: - Helpers

    private func screenContaining(point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            NSApp.activate()
            makeKeyAndOrderFront(nil)
        default:
            break
        }
        super.sendEvent(event)
    }
}
