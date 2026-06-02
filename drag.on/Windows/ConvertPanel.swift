import Cocoa
import SwiftUI
import Combine

/// A separate floating HUD panel for the image converter dialog.
final class ConvertPanel: NSPanel {

    private let store: LairStore
    private let converter: ImageConverter
    private let itemsToConvert: [FileItem]?
    var onDismissCallback: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init(store: LairStore, converter: ImageConverter, itemsToConvert: [FileItem]? = nil) {
        self.store = store
        self.converter = converter
        self.itemsToConvert = itemsToConvert

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: LairConstants.Convert.width, height: LairConstants.Convert.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        configurePanel()
        setupContent()
        setupUserDefaultsObserver()
        applyTheme()
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
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
    }

    // MARK: - Content

    private func setupContent() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: LairConstants.Convert.width, height: LairConstants.Convert.height))
        container.autoresizingMask = [.width, .height]
        contentView = container

        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = LairConstants.Convert.cornerRadius
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        container.addSubview(visualEffect)

        let convertView = ConvertView(
            store: store,
            converter: converter,
            itemsToConvert: itemsToConvert,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hosting = FirstMouseHostingView(rootView: convertView)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        visualEffect.addSubview(hosting)
    }

    // MARK: - Show / Dismiss

    func show(relativeTo lairFrame: NSRect) {
        let panelWidth: CGFloat = LairConstants.Convert.width
        let panelHeight: CGFloat = LairConstants.Convert.height

        let screen = NSScreen.screens.first(where: {
            $0.frame.contains(NSPoint(x: lairFrame.midX, y: lairFrame.midY))
        }) ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = screen else { return }
        let screenFrame = screen.visibleFrame

        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.midY - panelHeight / 2

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)

        alphaValue = 0
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        NSApp.activate()

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
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.onDismissCallback?()
        })
    }

    private func setupUserDefaultsObserver() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
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
