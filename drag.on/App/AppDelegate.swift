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
        lairWindow?.onDidHide = { [weak self] in
            self?.dragMonitor.shakeDetector.startCooldown()
        }
 
        // Apply saved shake sensitivity initially
        updateSensitivity()
 
        // Observe shake sensitivity changes dynamically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSensitivity),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
 
        dragMonitor.shakeDetector.onShakeDetected = { [weak self] location in
            guard let self = self, let window = self.lairWindow else { return }
            guard !window.isVisible && !window.isConvertPanelVisible else { return }
            window.show(near: location, isShake: true)
        }
 
        dragMonitor.onDragEnded = { [weak self] in
            self?.lairWindow?.handleDragEnded()
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

        let clipboardItem = NSMenuItem(
            title: "Open Lair from Clipboard",
            action: #selector(openLairFromClipboard),
            keyEquivalent: "v"
        )
        clipboardItem.keyEquivalentModifierMask = [.command, .shift]
        clipboardItem.target = self
        menu.addItem(clipboardItem)

        let clearItem = NSMenuItem(
            title: "Clear Lair",
            action: #selector(clearLair),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)
 
        let restoreItem = NSMenuItem(
            title: "Previous Lair",
            action: #selector(restorePreviousLair),
            keyEquivalent: "p"
        )
        restoreItem.keyEquivalentModifierMask = [.command, .shift]
        restoreItem.target = self
        menu.addItem(restoreItem)

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

    @objc private func openLairFromClipboard() {
        store.clearAll()
        store.pasteFromClipboard()
        let mouseLocation = NSEvent.mouseLocation
        lairWindow?.show(near: mouseLocation)
    }

    @objc private func clearLair() {
        store.clearAll()
    }
 
    @objc private func restorePreviousLair() {
        store.restorePreviousLair()
        let mouseLocation = NSEvent.mouseLocation
        lairWindow?.show(near: mouseLocation)
    }

    @objc private func openSettings() {
        NSApp.activate()
        if #available(macOS 14, *) {
            SettingsOpener.shared.openSettings()
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quitApp() {
        dragMonitor.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }

    @objc private func updateSensitivity() {
        let sensitivity = UserDefaults.standard.double(forKey: "shakeSensitivity")
        if sensitivity > 0 {
            dragMonitor.shakeDetector.requiredReversals = Int(sensitivity)
        }
    }

    // MARK: - NSMenuItemValidation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(restorePreviousLair) {
            return !store.previousItems.isEmpty
        }
        if menuItem.action == #selector(openLairFromClipboard) {
            return store.hasClipboardContent()
        }
        return true
    }
}
