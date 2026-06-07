import AppKit
import SwiftUI

@MainActor
public final class TourKitWindowController: NSObject {
    private var window: NSPanel?
    private var originalActivationPolicy: NSApplication.ActivationPolicy = .accessory

    public override init() {
        super.init()
    }

    public func present(
        pages: [TourPage],
        width: CGFloat = 600,
        continueButtonTitle: LocalizedStringKey = "Continue",
        finishButtonTitle: LocalizedStringKey = "Get Started",
        onFinish: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        // If already showing, bring it to front
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Save current activation policy and activate app
        originalActivationPolicy = NSApp.activationPolicy()
        if originalActivationPolicy != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        let slideshowView = TourSlideshowView(
            pages: pages,
            continueButtonTitle: continueButtonTitle,
            finishButtonTitle: finishButtonTitle,
            onFinish: { [weak self] in
                onFinish()
                self?.close()
            },
            onClose: { [weak self] in
                onClose()
                self?.close()
            }
        )

        let hostingView = NSHostingView(rootView: slideshowView)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 440)

        // Create a borderless floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        
        // Center the window on the main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - width) / 2
            let y = screenRect.origin.y + (screenRect.height - 440) / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = panel
        panel.makeKeyAndOrderFront(nil)
    }

    public func close() {
        guard let panel = window else { return }
        
        panel.orderOut(nil)
        self.window = nil

        // Restore activation policy
        if originalActivationPolicy != .regular {
            NSApp.setActivationPolicy(originalActivationPolicy)
        }
    }
}
