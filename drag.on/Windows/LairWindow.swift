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
    private var lastCompactModeValue: Bool = false
    private var wasShownByShake: Bool = false

    var onDidHide: (() -> Void)?
    var isExternalDragActive: Bool = false
    var isInternalDragActive: Bool = false {
        didSet {
            if !isInternalDragActive {
                if let pile = filePileView, pile.isReloadPending {
                    pile.reloadCards()
                }
            }
        }
    }
    private var activeDraggingCards = Set<FileCardNSView>()

    var isConvertPanelVisible: Bool {
        convertPanel?.isVisible ?? false
    }

    init(store: LairStore, converter: ImageConverter) {
        self.store = store
        self.converter = converter

        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        self.lastCompactModeValue = isCompact
        let initialWidth = isCompact ? LairConstants.Lair.compactWidth : LairConstants.Lair.width
        let initialHeight = isCompact ? LairConstants.Lair.compactHeight : LairConstants.Lair.height

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: initialWidth, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        configurePanel()
        setupContent()
        observeStoreChanges()
        setupUserDefaultsObserver()
        applyTheme()
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
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
    }

    // MARK: - Content Setup

    private func setupContent() {
        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        let currentWidth = isCompact ? LairConstants.Lair.compactWidth : LairConstants.Lair.width
        let currentHeight = isCompact ? LairConstants.Lair.compactHeight : LairConstants.Lair.height

        let dropView = DropTargetView(store: store)
        dropView.frame = NSRect(x: 0, y: 0, width: currentWidth, height: currentHeight)
        dropView.autoresizingMask = [.width, .height]
        contentView = dropView

        let visualEffect = NSVisualEffectView(frame: dropView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = LairConstants.Lair.cornerRadius
        visualEffect.layer?.masksToBounds = true
        // Borders are styled and drawn dynamically in SwiftUI LairView using Color("border-color")
        visualEffect.layer?.borderWidth = 0
        dropView.addSubview(visualEffect)

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

        let pile = FilePileNSView(store: store)
        pile.autoresizingMask = [.width, .height]
        visualEffect.addSubview(pile)
        self.filePileView = pile
        updateFilePileFrame()

        // No WindowDragHandleView added; background dragging is enabled window-wide.
    }

    // MARK: - Store Observation

    private func observeStoreChanges() {
        // Use withObservationTracking for @Observable store
        withObservationTracking {
            _ = store.items
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateFilePileFrame()
                self?.filePileView?.reloadCards()
                self?.observeStoreChanges()
            }
        }
    }

    private func updateFilePileFrame() {
        guard let pile = filePileView else { return }
        
        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        let isConvertShown = store.hasImages && !isCompact
        let currentWidth = isCompact ? LairConstants.Lair.compactWidth : LairConstants.Lair.width
        
        let y: CGFloat
        let height: CGFloat
        
        if isCompact {
            y = LairConstants.Lair.filePileYCompact
            height = LairConstants.Lair.filePileHeightCompact
        } else if isConvertShown {
            y = LairConstants.Lair.filePileYConvertShown
            height = LairConstants.Lair.filePileHeightConvertShown
        } else {
            y = LairConstants.Lair.filePileYStandard
            height = LairConstants.Lair.filePileHeightStandard
        }
        
        let newFrame = NSRect(
            x: LairConstants.Lair.filePileX,
            y: y,
            width: currentWidth - (LairConstants.Lair.filePileX * 2),
            height: height
        )
        
        if pile.frame != newFrame {
            pile.frame = newFrame
            pile.reloadCards()
        }
    }

    // MARK: - Show / Hide

    func show(near point: NSPoint, isShake: Bool = false) {
        self.wasShownByShake = isShake
        let screen = screenContaining(point: point) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        let panelWidth: CGFloat = isCompact ? LairConstants.Lair.compactWidth : LairConstants.Lair.width
        let panelHeight: CGFloat = isCompact ? LairConstants.Lair.compactHeight : LairConstants.Lair.height

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

    private func setupUserDefaultsObserver() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleCompactModeChange()
                self?.applyTheme()
            }
            .store(in: &cancellables)
    }
 
    private func handleCompactModeChange() {
        let currentCompact = UserDefaults.standard.bool(forKey: "compactMode")
        guard currentCompact != lastCompactModeValue else { return }
        lastCompactModeValue = currentCompact
        
        let targetWidth = currentCompact ? LairConstants.Lair.compactWidth : LairConstants.Lair.width
        let targetHeight = currentCompact ? LairConstants.Lair.compactHeight : LairConstants.Lair.height
        
        let currentFrame = frame
        let newX = currentFrame.midX - targetWidth / 2
        let newY = currentFrame.maxY - targetHeight
        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        
        setFrame(newFrame, display: true, animate: true)
        updateFilePileFrame()
    }

    private func applyTheme() {
        let theme = UserDefaults.standard.string(forKey: "appTheme") ?? "System"
        switch theme {
        case "Light":
            appearance = NSAppearance(named: .aqua)
        case "Dark":
            appearance = NSAppearance(named: .darkAqua)
        default:
            appearance = nil
        }
    }

    func hide() {
        wasShownByShake = false
        convertPanel?.dismiss()
        
        isExternalDragActive = false
        isInternalDragActive = false
        ignoresMouseEvents = false
        converter.reset()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.onDidHide?()
        })
    }
 
    func toggle(near point: NSPoint) {
        if isVisible { hide() } else { show(near: point) }
    }

    func cancelShakeAutoClose() {
        wasShownByShake = false
    }

    func handleDragEnded() {
        guard wasShownByShake else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if self.wasShownByShake {
                self.hide()
            }
        }
    }

    // MARK: - Convert Panel

    func showConvertPanel() {
        if convertPanel == nil {
            convertPanel = ConvertPanel(store: store, converter: converter)
        }
        
        let lairFrame = self.frame
        
        convertPanel?.onDismissCallback = { [weak self] in
            // When the convert panel is closed, restore the Lair window exactly where it was!
            self?.showAtFrame(lairFrame)
        }
        
        convertPanel?.show(relativeTo: lairFrame)
        
        // Hide the Lair window!
        self.hideWithoutDismissingConvert()
    }

    private func hideWithoutDismissingConvert() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.onDidHide?()
        })
    }

    // MARK: - Drag Card Lifecycle Tracking

    func registerDraggingCard(_ card: FileCardNSView) {
        activeDraggingCards.insert(card)
        isInternalDragActive = true
    }

    func unregisterDraggingCard(_ card: FileCardNSView) {
        activeDraggingCards.remove(card)
        if activeDraggingCards.isEmpty {
            isInternalDragActive = false
        }
    }

    func showAtFrame(_ frame: NSRect) {
        setFrame(frame, display: true)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
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
