import Cocoa
import os

/// Main application delegate managing the Lair window, drag monitoring, and menu bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private let store = LairStore()
    private let converter = ImageConverter()
    private var lairWindow: LairWindow?
    private let dragMonitor = DragMonitor()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        lairWindow = LairWindow(store: store, converter: converter)

        // Apply saved shake sensitivity
        let sensitivity = UserDefaults.standard.double(forKey: "shakeSensitivity")
        if sensitivity > 0 {
            dragMonitor.shakeDetector.requiredReversals = Int(sensitivity)
        }

        dragMonitor.shakeDetector.onShakeDetected = { [weak self] location in
            DispatchQueue.main.async {
                self?.lairWindow?.show(near: location)
            }
        }
        dragMonitor.startMonitoring()

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
                button.image = NSImage(systemSymbolName: "flame", accessibilityDescription: "Drag.on")
                button.image?.size = NSSize(width: 18, height: 18)
            }
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Drag.on", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(
            title: "Show Lair",
            action: #selector(toggleLair),
            keyEquivalent: "s"
        )
        showItem.keyEquivalentModifierMask = [.command, .shift]
        showItem.target = self
        menu.addItem(showItem)

        let clearItem = NSMenuItem(
            title: "Clear Lair",
            action: #selector(clearLair),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

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

    @objc private func openSettings() {
        NSApp.activate()
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quitApp() {
        dragMonitor.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
}
