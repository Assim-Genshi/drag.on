import Cocoa
import SwiftUI
import os

/// An NSViewRepresentable wrapper that provides native AppKit mouse hover, clicking,
/// and multi-file drag-out behavior inside SwiftUI grid cells.
struct DragSourceHelper: NSViewRepresentable {
    let item: FileItem
    let store: LairStore
    let isSelected: Bool
    let onSelectToggle: () -> Void
    let onHoverToggle: (Bool) -> Void
    let getSelectedItems: () -> [FileItem]

    func makeNSView(context: Context) -> DragSourceNSView {
        DragSourceNSView(
            item: item,
            store: store,
            isSelected: isSelected,
            onSelectToggle: onSelectToggle,
            onHoverToggle: onHoverToggle,
            getSelectedItems: getSelectedItems
        )
    }

    func updateNSView(_ nsView: DragSourceNSView, context: Context) {
        nsView.item = item
        nsView.store = store
        nsView.isSelected = isSelected
        nsView.onSelectToggle = onSelectToggle
        nsView.onHoverToggle = onHoverToggle
        nsView.getSelectedItems = getSelectedItems
    }
}

/// The AppKit view that intercepts drag and click events for a grid cell.
final class DragSourceNSView: NSView, NSDraggingSource {
    var item: FileItem
    var store: LairStore
    var isSelected: Bool
    var onSelectToggle: () -> Void
    var onHoverToggle: (Bool) -> Void
    var getSelectedItems: () -> [FileItem]

    private var dragOrigin: NSPoint?
    private var trackingArea: NSTrackingArea?
    private var mouseDownEvent: NSEvent?

    init(
        item: FileItem,
        store: LairStore,
        isSelected: Bool,
        onSelectToggle: @escaping () -> Void,
        onHoverToggle: @escaping (Bool) -> Void,
        getSelectedItems: @escaping () -> [FileItem]
    ) {
        self.item = item
        self.store = store
        self.isSelected = isSelected
        self.onSelectToggle = onSelectToggle
        self.onHoverToggle = onHoverToggle
        self.getSelectedItems = getSelectedItems
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func shouldDelayWindowOrdering(for event: NSEvent) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point) != nil ? self : nil
    }

    // MARK: - Tracking Area for Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let newArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(newArea)
        self.trackingArea = newArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverToggle(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverToggle(false)
    }

    // MARK: - Mouse Events for Drag & Click

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = dragOrigin else { return }

        let current = convert(event.locationInWindow, from: nil)
        let dx = current.x - origin.x
        let dy = current.y - origin.y
        let distance = sqrt(dx * dx + dy * dy)

        // Only start dragging if mouse moved past threshold
        guard distance > 5 else { return }
        dragOrigin = nil

        let selected = getSelectedItems()
        
        // Determine items to drag: if the dragged item is part of the selected set,
        // drag all selected items. Otherwise, drag only the current item.
        let itemsToDrag: [FileItem]
        if selected.contains(where: { $0.id == item.id }) {
            itemsToDrag = selected
        } else {
            itemsToDrag = [item]
        }

        guard !itemsToDrag.isEmpty else { return }

        // Generate the composite stack preview image
        let compositeImage = DragPreviewGenerator.compositeStackImage(for: itemsToDrag, totalCount: itemsToDrag.count)
        let compositeSize = DragPreviewGenerator.dragImageSize(for: itemsToDrag.count)

        // All dragging items share the exact same bounds/center relative to the mouse.
        // This ensures that even if AppKit/Finder attempts to apply a custom layout/formation,
        // all items remain perfectly overlapping, maintaining the unified stack visual.
        let dragRect = NSRect(
            x: current.x - compositeSize.width / 2,
            y: current.y - compositeSize.height / 2,
            width: compositeSize.width,
            height: compositeSize.height
        )

        var dragItems: [NSDraggingItem] = []

        for (offset, fileItem) in itemsToDrag.enumerated() {
            guard let url = fileItem.resolveURL() else { continue }

            let cleanURL = NSURL(fileURLWithPath: url.path)
            let dragItem = NSDraggingItem(pasteboardWriter: cleanURL)

            if offset == 0 {
                // First item carries the composite stack preview
                dragItem.setDraggingFrame(dragRect, contents: compositeImage)
            } else {
                // All other items are invisible — still registered for multi-file drop
                let emptyImage = NSImage(size: NSSize(width: 1, height: 1))
                dragItem.setDraggingFrame(dragRect, contents: emptyImage)
            }
            dragItems.append(dragItem)
        }

        let dragEvent = mouseDownEvent ?? event
        let session = beginDraggingSession(with: dragItems, event: dragEvent, source: self)
        session.draggingFormation = .none
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    override func mouseUp(with event: NSEvent) {
        if let origin = dragOrigin {
            let current = convert(event.locationInWindow, from: nil)
            let dx = current.x - origin.x
            let dy = current.y - origin.y
            let distance = sqrt(dx * dx + dy * dy)

            // Click detected if within threshold
            if distance <= 5 {
                onSelectToggle()
            }
        }
        dragOrigin = nil
        mouseDownEvent = nil
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        willBeginAt screenPoint: NSPoint
    ) {
        session.draggingFormation = .none
        if let lairWindow = window as? LairWindow {
            lairWindow.isInternalDragActive = true
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        movedTo screenPoint: NSPoint
    ) {
        session.draggingFormation = .none
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if let lairWindow = window as? LairWindow {
            lairWindow.isInternalDragActive = false
        }
        
        let windowPoint = window?.convertPoint(fromScreen: screenPoint) ?? .zero
        let localDropPoint = self.convert(windowPoint, from: nil)
        
        let startOffsetX = localDropPoint.x - bounds.midX
        let startOffsetY = localDropPoint.y - bounds.midY
        
        performBounceAnimation(offsetX: startOffsetX, offsetY: startOffsetY, delay: 0.0)
    }

    /// Performs a high-performance, direction-aware slide back and a soft impact bounce/wiggle.
    func performBounceAnimation(offsetX: CGFloat, offsetY: CGFloat, delay: TimeInterval) {
        guard let layer = self.layer else { return }
        
        layer.removeAnimation(forKey: "bounceTranslationX")
        layer.removeAnimation(forKey: "bounceTranslationY")
        layer.removeAnimation(forKey: "bounceRotation")
        
        let currentTime = CACurrentMediaTime()
        let beginTime = currentTime + delay
        let duration: TimeInterval = 0.52
        
        // Cap the maximum initial offset to keep the visual slide within local limits
        let distance = sqrt(offsetX * offsetX + offsetY * offsetY)
        var finalOffsetX = offsetX
        var finalOffsetY = offsetY
        let maxDistance: CGFloat = 300.0
        if distance > maxDistance {
            finalOffsetX = (offsetX / distance) * maxDistance
            finalOffsetY = (offsetY / distance) * maxDistance
        }
        
        // Calculate a soft, capped overshoot on impact (opposite direction)
        var overshootX = -finalOffsetX * 0.12
        var overshootY = -finalOffsetY * 0.12
        let maxOvershoot: CGFloat = 10.0
        let overshootDist = sqrt(overshootX * overshootX + overshootY * overshootY)
        if overshootDist > maxOvershoot {
            overshootX = (overshootX / overshootDist) * maxOvershoot
            overshootY = (overshootY / overshootDist) * maxOvershoot
        }
        
        // Rebound offset (soft settling)
        let reboundX = -overshootX * 0.4
        let reboundY = -overshootY * 0.4
        
        // 1. Translation X Timeline
        let animX = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animX.values = [
            finalOffsetX,
            overshootX,
            reboundX,
            0
        ]
        animX.keyTimes = [0, 0.44, 0.72, 1.0] as [NSNumber]
        animX.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        animX.duration = duration
        animX.beginTime = beginTime
        animX.fillMode = .both
        
        // 2. Translation Y Timeline
        let animY = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animY.values = [
            finalOffsetY,
            overshootY,
            reboundY,
            0
        ]
        animY.keyTimes = animX.keyTimes
        animY.timingFunctions = animX.timingFunctions
        animY.duration = duration
        animY.beginTime = beginTime
        animY.fillMode = .both
        
        // 3. Soft Rotational Wiggle (only triggered on impact to simulate hitting the grid cell)
        let animRot = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let maxRot: Double = 0.012 * (Double.random(in: 0.7...1.3)) * (Double.random(in: 0...1) > 0.5 ? 1.0 : -1.0)
        animRot.values = [
            0,
            0,
            maxRot,
            -maxRot * 0.4,
            0
        ]
        animRot.keyTimes = [0, 0.36, 0.56, 0.8, 1.0] as [NSNumber]
        animRot.timingFunctions = animX.timingFunctions
        animRot.duration = duration
        animRot.beginTime = beginTime
        animRot.fillMode = .both
        
        layer.add(animX, forKey: "bounceTranslationX")
        layer.add(animY, forKey: "bounceTranslationY")
        layer.add(animRot, forKey: "bounceRotation")
    }

    // MARK: - Contextual Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let url = item.resolveURL() else { return nil }
        
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Detect if directory
        var isDir: ObjCBool = false
        let fileExists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let isDirectory = fileExists && isDir.boolValue
        
        if isDirectory {
            // Folder Specific Menu
            
            // 1. Open
            let openItem = NSMenuItem(
                title: LairConstants.Lair.openActionText,
                action: #selector(openCommand(_:)),
                keyEquivalent: ""
            )
            openItem.target = self
            if let openIcon = NSImage(systemSymbolName: LairConstants.Lair.openActionIcon, accessibilityDescription: nil) {
                openItem.image = openIcon
            }
            openItem.isEnabled = true
            let openItemFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            openItem.attributedTitle = NSAttributedString(
                string: LairConstants.Lair.openActionText,
                attributes: [.font: openItemFont]
            )
            menu.addItem(openItem)
            
            // 2. Open in Finder
            let openInFinderItem = NSMenuItem(
                title: LairConstants.Lair.openInFinderActionText,
                action: #selector(openInFinderCommand(_:)),
                keyEquivalent: ""
            )
            openInFinderItem.target = self
            if let openInFinderIcon = NSImage(systemSymbolName: LairConstants.Lair.openInFinderActionIcon, accessibilityDescription: nil) {
                openInFinderItem.image = openInFinderIcon
            }
            openInFinderItem.isEnabled = true
            menu.addItem(openInFinderItem)
            
            // 3. Open in Terminal
            let openInTerminalItem = NSMenuItem(
                title: LairConstants.Lair.openInTerminalActionText,
                action: #selector(openInTerminalCommand(_:)),
                keyEquivalent: ""
            )
            openInTerminalItem.target = self
            if let openInTerminalIcon = NSImage(systemSymbolName: LairConstants.Lair.openInTerminalActionIcon, accessibilityDescription: nil) {
                openInTerminalItem.image = openInTerminalIcon
            }
            openInTerminalItem.isEnabled = true
            menu.addItem(openInTerminalItem)
            
            // 3.5 Open With (Submenu)
            let openWithSubmenu = NSMenu()
            openWithSubmenu.autoenablesItems = false
            
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
            if !apps.isEmpty {
                for appURL in apps {
                    let appName = FileManager.default.displayName(atPath: appURL.path)
                    let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                    appIcon.size = NSSize(width: 16, height: 16)
                    
                    let appItem = NSMenuItem(
                        title: appName,
                        action: #selector(openWithAppCommand(_:)),
                        keyEquivalent: ""
                    )
                    appItem.target = self
                    appItem.representedObject = appURL
                    appItem.image = appIcon
                    appItem.isEnabled = true
                    openWithSubmenu.addItem(appItem)
                }
                openWithSubmenu.addItem(NSMenuItem.separator())
            }
            
            let otherAppItem = NSMenuItem(
                title: "Other…",
                action: #selector(openWithOtherCommand(_:)),
                keyEquivalent: ""
            )
            otherAppItem.target = self
            otherAppItem.isEnabled = true
            openWithSubmenu.addItem(otherAppItem)
            
            let openWithItem = NSMenuItem(
                title: LairConstants.Lair.openWithActionText,
                action: nil,
                keyEquivalent: ""
            )
            openWithItem.submenu = openWithSubmenu
            if let openWithIcon = NSImage(systemSymbolName: LairConstants.Lair.openWithActionIcon, accessibilityDescription: nil) {
                openWithItem.image = openWithIcon
            }
            openWithItem.isEnabled = true
            menu.addItem(openWithItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // 4. Reveal in Finder
            let revealItem = NSMenuItem(
                title: LairConstants.Lair.revealInFinderActionText,
                action: #selector(revealInFinderCommand(_:)),
                keyEquivalent: ""
            )
            revealItem.target = self
            if let revealIcon = NSImage(systemSymbolName: LairConstants.Lair.revealInFinderActionIcon, accessibilityDescription: nil) {
                revealItem.image = revealIcon
            }
            revealItem.isEnabled = true
            menu.addItem(revealItem)
            
            // 5. Copy Path
            let copyPathItem = NSMenuItem(
                title: LairConstants.Lair.copyPathActionText,
                action: #selector(copyPathCommand(_:)),
                keyEquivalent: ""
            )
            copyPathItem.target = self
            if let copyPathIcon = NSImage(systemSymbolName: LairConstants.Lair.copyPathActionIcon, accessibilityDescription: nil) {
                copyPathItem.image = copyPathIcon
            }
            copyPathItem.isEnabled = true
            menu.addItem(copyPathItem)
            
            // 6. Rename...
            let renameItemMenu = NSMenuItem(
                title: LairConstants.Lair.renameActionText,
                action: #selector(renameCommand(_:)),
                keyEquivalent: ""
            )
            renameItemMenu.target = self
            if let renameIcon = NSImage(systemSymbolName: LairConstants.Lair.renameActionIcon, accessibilityDescription: nil) {
                renameItemMenu.image = renameIcon
            }
            renameItemMenu.isEnabled = true
            menu.addItem(renameItemMenu)
            
            // 7. Duplicate
            let duplicateItemMenu = NSMenuItem(
                title: LairConstants.Lair.duplicateActionText,
                action: #selector(duplicateCommand(_:)),
                keyEquivalent: ""
            )
            duplicateItemMenu.target = self
            if let duplicateIcon = NSImage(systemSymbolName: LairConstants.Lair.duplicateActionIcon, accessibilityDescription: nil) {
                duplicateItemMenu.image = duplicateIcon
            }
            duplicateItemMenu.isEnabled = true
            menu.addItem(duplicateItemMenu)
            
            // 8. Compress
            let compressItemMenu = NSMenuItem(
                title: "Compress",
                action: #selector(compressCommand(_:)),
                keyEquivalent: ""
            )
            compressItemMenu.target = self
            if let compressIcon = NSImage(systemSymbolName: LairConstants.Lair.compressZipActionIcon, accessibilityDescription: nil) {
                compressItemMenu.image = compressIcon
            }
            compressItemMenu.isEnabled = true
            menu.addItem(compressItemMenu)
            
        } else {
            // File Specific Menu
            
            // 1. Open
            let openItem = NSMenuItem(
                title: LairConstants.Lair.openActionText,
                action: #selector(openCommand(_:)),
                keyEquivalent: ""
            )
            openItem.target = self
            if let openIcon = NSImage(systemSymbolName: LairConstants.Lair.openActionIcon, accessibilityDescription: nil) {
                openItem.image = openIcon
            }
            openItem.isEnabled = true
            let openItemFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            openItem.attributedTitle = NSAttributedString(
                string: LairConstants.Lair.openActionText,
                attributes: [.font: openItemFont]
            )
            menu.addItem(openItem)
            
            // 2. Open With (Submenu)
            let openWithSubmenu = NSMenu()
            openWithSubmenu.autoenablesItems = false
            
            let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
            if !apps.isEmpty {
                for appURL in apps {
                    let appName = FileManager.default.displayName(atPath: appURL.path)
                    let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                    appIcon.size = NSSize(width: 16, height: 16)
                    
                    let appItem = NSMenuItem(
                        title: appName,
                        action: #selector(openWithAppCommand(_:)),
                        keyEquivalent: ""
                    )
                    appItem.target = self
                    appItem.representedObject = appURL
                    appItem.image = appIcon
                    appItem.isEnabled = true
                    openWithSubmenu.addItem(appItem)
                }
                openWithSubmenu.addItem(NSMenuItem.separator())
            }
            
            let otherAppItem = NSMenuItem(
                title: "Other…",
                action: #selector(openWithOtherCommand(_:)),
                keyEquivalent: ""
            )
            otherAppItem.target = self
            otherAppItem.isEnabled = true
            openWithSubmenu.addItem(otherAppItem)
            
            let openWithItem = NSMenuItem(
                title: LairConstants.Lair.openWithActionText,
                action: nil,
                keyEquivalent: ""
            )
            openWithItem.submenu = openWithSubmenu
            if let openWithIcon = NSImage(systemSymbolName: LairConstants.Lair.openWithActionIcon, accessibilityDescription: nil) {
                openWithItem.image = openWithIcon
            }
            openWithItem.isEnabled = true
            menu.addItem(openWithItem)
            
            // 3. Reveal in Finder
            let revealItem = NSMenuItem(
                title: LairConstants.Lair.revealInFinderActionText,
                action: #selector(revealInFinderCommand(_:)),
                keyEquivalent: ""
            )
            revealItem.target = self
            if let revealIcon = NSImage(systemSymbolName: LairConstants.Lair.revealInFinderActionIcon, accessibilityDescription: nil) {
                revealItem.image = revealIcon
            }
            revealItem.isEnabled = true
            menu.addItem(revealItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // 4. Copy Path
            let copyPathItem = NSMenuItem(
                title: LairConstants.Lair.copyPathActionText,
                action: #selector(copyPathCommand(_:)),
                keyEquivalent: ""
            )
            copyPathItem.target = self
            if let copyPathIcon = NSImage(systemSymbolName: LairConstants.Lair.copyPathActionIcon, accessibilityDescription: nil) {
                copyPathItem.image = copyPathIcon
            }
            copyPathItem.isEnabled = true
            menu.addItem(copyPathItem)
            
            // 5. Rename...
            let renameItemMenu = NSMenuItem(
                title: LairConstants.Lair.renameActionText,
                action: #selector(renameCommand(_:)),
                keyEquivalent: ""
            )
            renameItemMenu.target = self
            if let renameIcon = NSImage(systemSymbolName: LairConstants.Lair.renameActionIcon, accessibilityDescription: nil) {
                renameItemMenu.image = renameIcon
            }
            renameItemMenu.isEnabled = true
            menu.addItem(renameItemMenu)
            
            // 6. Duplicate
            let duplicateItemMenu = NSMenuItem(
                title: LairConstants.Lair.duplicateActionText,
                action: #selector(duplicateCommand(_:)),
                keyEquivalent: ""
            )
            duplicateItemMenu.target = self
            if let duplicateIcon = NSImage(systemSymbolName: LairConstants.Lair.duplicateActionIcon, accessibilityDescription: nil) {
                duplicateItemMenu.image = duplicateIcon
            }
            duplicateItemMenu.isEnabled = true
            menu.addItem(duplicateItemMenu)
            
            // 7. Compress ZIP
            let compressItemMenu = NSMenuItem(
                title: LairConstants.Lair.compressZipActionText,
                action: #selector(compressCommand(_:)),
                keyEquivalent: ""
            )
            compressItemMenu.target = self
            if let compressIcon = NSImage(systemSymbolName: LairConstants.Lair.compressZipActionIcon, accessibilityDescription: nil) {
                compressItemMenu.image = compressIcon
            }
            compressItemMenu.isEnabled = true
            menu.addItem(compressItemMenu)
            
            // 8. Convert
            let convertItemMenu = NSMenuItem(
                title: LairConstants.Lair.convertActionText,
                action: #selector(convertCommand(_:)),
                keyEquivalent: ""
            )
            convertItemMenu.target = self
            if let convertIcon = NSImage(systemSymbolName: LairConstants.Lair.convertActionIcon, accessibilityDescription: nil) {
                convertItemMenu.image = convertIcon
            }
            convertItemMenu.isEnabled = item.isImage
            menu.addItem(convertItemMenu)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Remove from Lair
        let removeItem = NSMenuItem(
            title: LairConstants.Lair.removeFromLairActionText,
            action: #selector(removeFromLairCommand(_:)),
            keyEquivalent: ""
        )
        removeItem.target = self
        if let removeIcon = NSImage(systemSymbolName: LairConstants.Lair.removeFromLairActionIcon, accessibilityDescription: nil) {
            removeItem.image = removeIcon
        }
        removeItem.isEnabled = true
        menu.addItem(removeItem)
        
        return menu
    }

    // MARK: - Menu Actions

    @objc private func openCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openInFinderCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openInTerminalCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        let preferredTerminal = UserDefaults.standard.string(forKey: "preferredTerminal") ?? "Terminal.app"
        let bundleID: String
        switch preferredTerminal {
        case "iTerm2":
            bundleID = "com.googlecode.iterm2"
        case "Warp":
            bundleID = "dev.warp.Warp-Stable"
        default:
            bundleID = "com.apple.Terminal"
        }
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
                NSWorkspace.shared.open([url], withApplicationAt: terminalURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }

    @objc private func revealInFinderCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func copyPathCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.path, forType: .string)
    }

    @objc private func renameCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        
        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.informativeText = "Enter a new name for '\(url.lastPathComponent)':"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.stringValue = url.lastPathComponent
        alert.accessoryView = textField
        
        let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
        textField.currentEditor()?.selectedRange = NSRange(location: 0, length: nameWithoutExtension.count)
        
        NSApp.activate(ignoringOtherApps: true)
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty && newName != url.lastPathComponent else { return }
            
            let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            do {
                try FileManager.default.moveItem(at: url, to: newURL)
                store.replaceFile(id: item.id, with: newURL)
            } catch {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Rename Failed"
                errorAlert.informativeText = error.localizedDescription
                errorAlert.addButton(withTitle: "OK")
                errorAlert.runModal()
            }
        }
    }

    @objc private func duplicateCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        let baseDir = url.deletingLastPathComponent()
        let nameWithoutExt = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var copyName = "\(nameWithoutExt) copy"
        var destURL = baseDir.appendingPathComponent(ext.isEmpty ? copyName : "\(copyName).\(ext)")
        var counter = 1
        
        while FileManager.default.fileExists(atPath: destURL.path) {
            counter += 1
            copyName = "\(nameWithoutExt) copy \(counter)"
            destURL = baseDir.appendingPathComponent(ext.isEmpty ? copyName : "\(copyName).\(ext)")
        }
        
        do {
            try FileManager.default.copyItem(at: url, to: destURL)
            store.addFile(url: destURL)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Duplicate Failed"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc private func compressCommand(_ sender: Any) {
        guard let url = item.resolveURL() else { return }
        let baseDir = url.deletingLastPathComponent()
        let nameWithoutExt = url.deletingPathExtension().lastPathComponent
        
        var destZipURL = baseDir.appendingPathComponent("\(nameWithoutExt).zip")
        var counter = 1
        while FileManager.default.fileExists(atPath: destZipURL.path) {
            counter += 1
            destZipURL = baseDir.appendingPathComponent("\(nameWithoutExt) \(counter).zip")
        }
        
        Task { @MainActor in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", url.path, destZipURL.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    self.store.addFile(url: destZipURL)
                } else {
                    self.showErrorAlert(title: "Compression Failed", message: "Compression failed with exit code \(process.terminationStatus)")
                }
            } catch {
                self.showErrorAlert(title: "Compression Failed", message: error.localizedDescription)
            }
        }
    }

    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func convertCommand(_ sender: Any) {
        if let window = self.window as? LairWindow {
            window.showConvertPanel()
        }
    }

    @objc private func removeFromLairCommand(_ sender: Any) {
        store.removeFile(id: item.id)
    }

    @objc private func openWithAppCommand(_ sender: NSMenuItem) {
        guard let appURL = sender.representedObject as? URL,
              let fileURL = item.resolveURL() else { return }
        NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func openWithOtherCommand(_ sender: Any) {
        guard let fileURL = item.resolveURL() else { return }
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application, .executable]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        
        NSApp.activate(ignoringOtherApps: true)
        if openPanel.runModal() == .OK, let appURL = openPanel.url {
            NSWorkspace.shared.open([fileURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
