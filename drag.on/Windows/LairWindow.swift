import Cocoa
import SwiftUI
import Combine

/// A floating, translucent panel that acts as the Drag.on Lair drop zone.
final class LairWindow: NSPanel {

    private let store: LairStore
    private let converter: ImageConverter
    private let uiState = LairUIState()
    private var hostingView: FirstMouseHostingView<LairView>?
    private var filePileView: FilePileNSView?
    private var dropOverlay: DropOverlayView?
    private var convertPanel: ConvertPanel?
    private var cancellables = Set<AnyCancellable>()
    private var lastCompactModeValue: Bool = false
    private var wasShownByShake: Bool = false
    private var lastItemIds: [UUID] = []

    var onDidHide: (() -> Void)?
    var isExternalDragActive: Bool = false {
        didSet {
            guard isExternalDragActive != oldValue else { return }
            uiState.isExternalDragActive = isExternalDragActive
            if isExternalDragActive {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            }
        }
    }
    var isInternalDragActive: Bool = false {
        didSet {
            guard isInternalDragActive != oldValue else { return }
            
            // Hide the cards immediately when dragging starts, fade back in when ends
            if isInternalDragActive {
                filePileView?.alphaValue = 0.0
            } else {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    filePileView?.animator().alphaValue = 1.0
                }
            }
            
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
        self.lastItemIds = store.items.map(\.id)

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

        let dropView = DropTargetView()
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

        let lairView = LairView(
            store: store,
            uiState: uiState,
            onClose: { [weak self] in
                self?.hide()
            },
            onConvert: { [weak self] in
                self?.showConvertPanel()
            },
            onConvertSelected: { [weak self] selectedItems in
                self?.showConvertPanel(itemsToConvert: selectedItems)
            }
        )
        let hosting = FirstMouseHostingView(rootView: lairView)
        hosting.frame = dropView.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        visualEffect.addSubview(hosting)
        self.hostingView = hosting

        let pile = FilePileNSView(store: store)
        pile.autoresizingMask = []
        visualEffect.addSubview(pile)
        self.filePileView = pile
        updateFilePileFrame()

        // Add drop overlay as the topmost subview — sole drop target for the window.
        // Sits above all cards and SwiftUI content; invisible to clicks.
        let overlay = DropOverlayView(store: store)
        overlay.frame = visualEffect.bounds
        overlay.autoresizingMask = [.width, .height]
        visualEffect.addSubview(overlay)
        self.dropOverlay = overlay

        // No WindowDragHandleView added; background dragging is enabled window-wide.
    }

    // MARK: - Store Observation

    private func observeStoreChanges() {
        // Use withObservationTracking for @Observable store and uiState
        withObservationTracking {
            _ = store.items
            _ = uiState.isManagementPanelActive
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.handleStoreOrUIChanges()
                self?.observeStoreChanges()
            }
        }
    }

    private func handleStoreOrUIChanges() {
        if store.items.isEmpty {
            uiState.isManagementPanelActive = false
            uiState.selectedItemIDs.removeAll()
        }
        updateWindowFrameAndPileVisibility()
        
        let currentItemIds = store.items.map(\.id)
        let itemsChanged = currentItemIds != lastItemIds
        lastItemIds = currentItemIds
        
        if !uiState.isManagementPanelActive {
            if itemsChanged || filePileView?.isReloadPending == true {
                filePileView?.reloadCards()
            }
        } else {
            if itemsChanged {
                filePileView?.isReloadPending = true
            }
        }
    }

    private func updateFilePileFrame() {
        guard let pile = filePileView else { return }
        if uiState.isManagementPanelActive { return }
        
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

    private func updateWindowFrameAndPileVisibility() {
        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        let isManagement = uiState.isManagementPanelActive
        
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        
        if isManagement {
            targetWidth = LairConstants.Lair.managementWidth
            targetHeight = LairConstants.Lair.managementHeight
            // Smoothly fade out the file pile view before hiding it
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                filePileView?.animator().alphaValue = 0.0
            } completionHandler: { [weak self] in
                if self?.uiState.isManagementPanelActive == true {
                    self?.filePileView?.isHidden = true
                }
            }
        } else {
            targetWidth = isCompact ? LairConstants.Lair.compactWidth : LairConstants.Lair.width
            targetHeight = isCompact ? LairConstants.Lair.compactHeight : LairConstants.Lair.height
            filePileView?.isHidden = false
            filePileView?.alphaValue = 0.0
            // Smoothly fade the file pile back in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                filePileView?.animator().alphaValue = 1.0
            }
        }
        
        let currentFrame = frame
        let newX = currentFrame.midX - targetWidth / 2
        let newY = currentFrame.maxY - targetHeight
        let newFrame = NSRect(x: newX, y: newY, width: targetWidth, height: targetHeight)
        
        if currentFrame != newFrame {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            }
        }
        
        updateFilePileFrame()
    }

    // MARK: - Show / Hide

    func show(near point: NSPoint, isShake: Bool = false) {
        self.wasShownByShake = isShake
        let screen = screenContaining(point: point) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame

        let isCompact = UserDefaults.standard.bool(forKey: "compactMode")
        let isManagement = uiState.isManagementPanelActive
        
        let panelWidth: CGFloat
        let panelHeight: CGFloat
        
        if isManagement {
            panelWidth = LairConstants.Lair.managementWidth
            panelHeight = LairConstants.Lair.managementHeight
        } else {
            panelWidth = isCompact ? LairConstants.Lair.compactWidth : LairConstants.Lair.width
            panelHeight = isCompact ? LairConstants.Lair.compactHeight : LairConstants.Lair.height
        }

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
        updateWindowFrameAndPileVisibility()
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

    func showConvertPanel(itemsToConvert: [FileItem]? = nil) {
        convertPanel = ConvertPanel(store: store, converter: converter, itemsToConvert: itemsToConvert)
        
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
}
