import SwiftUI
import Cocoa

@main
struct drag_onApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let store = ShelfStore()
    private let converter = ImageConverter()
    private var lairWindow: ShelfWindow?
    private let dragMonitor = DragMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)

        // Create lair window
        lairWindow = ShelfWindow(store: store, converter: converter)

        // Wire up shake detection
        dragMonitor.shakeDetector.onShakeDetected = { [weak self] location in
            DispatchQueue.main.async {
                self?.lairWindow?.show(near: location)
            }
        }

        // Start monitoring drags globally
        dragMonitor.startMonitoring()

        // Setup menu bar
        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor.stopMonitoring()
    }

    // MARK: - Menu Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            } else {
                // Fallback to system symbol if asset not found
                button.image = NSImage(systemSymbolName: "flame", accessibilityDescription: "Drag.on")
                button.image?.size = NSSize(width: 18, height: 18)
            }
        }

        let menu = NSMenu()

        // Title
        let titleItem = NSMenuItem(title: "Drag.on", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Show / Hide Lair
        let showItem = NSMenuItem(
            title: "Show Lair",
            action: #selector(toggleLair),
            keyEquivalent: "s"
        )
        showItem.keyEquivalentModifierMask = [.command, .shift]
        showItem.target = self
        menu.addItem(showItem)

        // Clear Lair
        let clearItem = NSMenuItem(
            title: "Clear Lair",
            action: #selector(clearLair),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Drag.on",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleLair() {
        let mouseLocation = NSEvent.mouseLocation
        lairWindow?.toggle(near: mouseLocation)
    }

    @objc private func clearLair() {
        store.clearAll()
    }

    @objc private func quitApp() {
        dragMonitor.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
