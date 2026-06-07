import SwiftUI
import Quartz

// MARK: - LairView (Main Lair Overlay)

struct LairView: View {
    var store: LairStore
    var uiState: LairUIState
    var onClose: () -> Void
    var onConvert: () -> Void
    var onConvertSelected: ([FileItem]) -> Void

    @State private var isHoveringConvert = false
    @State private var isHoveringFileCount = false
    @AppStorage("compactMode") private var compactMode = false
    @Environment(\.openSettings) private var openSettings

    // MARK: - Theme Colors

    private var mainSurface: Color {
        Color("main-surfece")
    }

    private var secondarySurface: Color {
        Color("Secondary-surfece")
    }

    private var borderColor: Color {
        Color("border-color")
    }

    private var content100: Color {
        Color("content-100")
    }

    private var content200: Color {
        Color("content-200")
    }

    var body: some View {
        ZStack {
            if store.items.isEmpty {
                dashedContainerBorder
                    .transition(.opacity)
            }

            if uiState.isManagementPanelActive {
                LairManagerView(
                    store: store,
                    uiState: uiState,
                    onClose: onClose,
                    onConvertSelected: onConvertSelected
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ZStack {
                    mainLairContent
                    topBar
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius)
                .fill(uiState.isExternalDragActive ? Color.cyanDream.opacity(LairConstants.Lair.dragActiveBgOpacity) : mainSurface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius)
                .stroke(
                    uiState.isExternalDragActive ? Color.skyblue : borderColor,
                    lineWidth: uiState.isExternalDragActive ? LairConstants.Lair.dragActiveBorderWidth : LairConstants.Lair.dragInactiveBorderWidth
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius))
        .animation(.smooth(duration: 0.25), value: uiState.isExternalDragActive)
        .onAppear {
            SettingsOpener.shared.register {
                openSettings()
            }
        }
    }

    // MARK: - Dashed Container Border

    private var dashedContainerBorder: some View {
        RoundedRectangle(cornerRadius: 22)
            .strokeBorder(
                uiState.isExternalDragActive ? Color.cyanDream : borderColor,
                style: StrokeStyle(lineWidth: 1.5, dash: [9, 4])
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 52)
            .allowsHitTesting(false)
    }

    // MARK: - Main Lair Content

    private var mainLairContent: some View {
        VStack(spacing: 0) {
            // Drag handle pill
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 10)
                    .fill(borderColor)
                    .frame(width: 36, height: 4)
                Spacer()
            }
            .padding(.top, 4)
            .allowsHitTesting(false)

            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image("drag-on")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(uiState.isExternalDragActive ? Color.cyanDream : content200)
                    Text("Drop Artifact here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(uiState.isExternalDragActive ? Color.cyanDream : content200)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 48)
                .contentShape(Rectangle())
                .contextMenu {
                    Button(action: {
                        store.pasteFromClipboard()
                    }) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .disabled(!store.hasClipboardContent())
                }
            } else {
                Spacer()

                bottomBar
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button(action: {
                withAnimation(.snappy(duration: 0.3)) {
                    uiState.isManagementPanelActive = true
                }
            }) {
                FileCountLabel(items: store.items)
            }
            .buttonStyle(.plain)
            .scaleEffect(isHoveringFileCount ? 1.05 : 1.0)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHoveringFileCount = hovering
                }
            }
            .pointerCursor()

            if store.hasImages && !compactMode {
                Button(action: onConvert) {
                    HStack(spacing: 8) {
                        WandIcon(size: 13, weight: .bold)
                            .foregroundStyle(.white)
                        Text("Convert")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(
                        Capsule()
                            .fill(.skyblue)
                    )
                    .overlay(
                        Capsule()
                            .stroke(.cyanDream, lineWidth: 1.0)
                    )
                    .scaleEffect(isHoveringConvert ? 1.03 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHoveringConvert = hovering
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                LairCircleButton(systemName: "xmark", action: {
                    store.clearAll()
                    onClose()
                })

                Spacer()

                if !store.items.isEmpty {
                    LairCircleButton(systemName: LairConstants.Lair.menuIconName, action: {
                        showChevronMenu()
                    })
                    .pointerCursor()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Native Chevron Menu

    private func showChevronMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let items = store.items
        guard !items.isEmpty else { return }

        if items.count == 1, let singleItem = items.first, let url = singleItem.resolveURL() {
            buildSingleItemMenu(menu: menu, item: singleItem, url: url)
        } else {
            buildMultiItemMenu(menu: menu, items: items)
        }

        // Present the menu at the current mouse location
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }

    // MARK: - Single Item Menu

    private func buildSingleItemMenu(menu: NSMenu, item: FileItem, url: URL) {
        let isDir = isDirectory(url: url)

        // Open (bold)
        menu.addActionItem(
            title: LairConstants.Lair.openActionText,
            systemImage: LairConstants.Lair.openActionIcon,
            isBold: true
        ) {
            NSWorkspace.shared.open(url)
        }

        // Open in Finder (folder only)
        if isDir {
            menu.addActionItem(
                title: LairConstants.Lair.openInFinderActionText,
                systemImage: LairConstants.Lair.openInFinderActionIcon
            ) {
                NSWorkspace.shared.open(url)
            }

            // Open in Terminal (folder only)
            menu.addActionItem(
                title: LairConstants.Lair.openInTerminalActionText,
                systemImage: LairConstants.Lair.openInTerminalActionIcon
            ) {
                openInTerminal(url: url)
            }
        }

        // Open With submenu
        buildOpenWithSubmenu(menu: menu, url: url)

        menu.addItem(NSMenuItem.separator())

        // Reveal in Finder
        menu.addActionItem(
            title: LairConstants.Lair.revealInFinderActionText,
            systemImage: LairConstants.Lair.revealInFinderActionIcon
        ) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        // Quick Look
        menu.addActionItem(
            title: "Quick Look",
            systemImage: "eye"
        ) { [store] in
            quickLookItems(store.items)
        }

        // AirDrop
        let airdropItem = menu.addActionItem(
            title: "AirDrop"
        ) {
            airdropItems(urls: [url])
        }
        if let airdropImage = NSImage(named: "airdrop-60") {
            airdropImage.size = NSSize(width: 16, height: 16)
            airdropItem.image = airdropImage
        }

        menu.addItem(NSMenuItem.separator())

        // Copy Path
        menu.addActionItem(
            title: LairConstants.Lair.copyPathActionText,
            systemImage: LairConstants.Lair.copyPathActionIcon
        ) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(url.path, forType: .string)
        }

        // Rename
        menu.addActionItem(
            title: LairConstants.Lair.renameActionText,
            systemImage: LairConstants.Lair.renameActionIcon
        ) {
            renameItem(item, url: url)
        }

        // Duplicate
        menu.addActionItem(
            title: LairConstants.Lair.duplicateActionText,
            systemImage: LairConstants.Lair.duplicateActionIcon
        ) {
            duplicateItem(url: url)
        }

        // Compress ZIP
        menu.addActionItem(
            title: LairConstants.Lair.compressZipActionText,
            systemImage: LairConstants.Lair.compressZipActionIcon
        ) {
            compressItem(url: url)
        }

        // Convert (files only, images only)
        if !isDir {
            menu.addActionItem(
                title: LairConstants.Lair.convertActionText,
                systemImage: LairConstants.Lair.convertActionIcon,
                isEnabled: item.isImage
            ) {
                onConvert()
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Remove from Lair
        menu.addActionItem(
            title: LairConstants.Lair.removeFromLairActionText,
            systemImage: LairConstants.Lair.removeFromLairActionIcon
        ) { [store] in
            store.removeFile(id: item.id)
        }

        // Clear Lair
        menu.addActionItem(
            title: LairConstants.Lair.clearActionText,
            systemImage: LairConstants.Lair.clearActionIcon
        ) { [store] in
            store.clearAll()
        }
    }

    // MARK: - Multi-Item Menu

    private func buildMultiItemMenu(menu: NSMenu, items: [FileItem]) {
        let resolvedURLs = items.compactMap { $0.resolveURL() }

        // Reveal All in Finder
        menu.addActionItem(
            title: "Reveal All in Finder",
            systemImage: LairConstants.Lair.revealInFinderActionIcon
        ) {
            NSWorkspace.shared.activateFileViewerSelecting(resolvedURLs)
        }

        // Quick Look (all items)
        menu.addActionItem(
            title: "Quick Look",
            systemImage: "eye"
        ) {
            quickLookItems(items)
        }

        // AirDrop (all items)
        let airdropItem = menu.addActionItem(
            title: "AirDrop"
        ) {
            airdropItems(urls: resolvedURLs)
        }
        if let airdropImage = NSImage(named: "airdrop-60") {
            airdropImage.size = NSSize(width: 16, height: 16)
            airdropItem.image = airdropImage
        }

        menu.addItem(NSMenuItem.separator())

        // Compress All ZIP
        menu.addActionItem(
            title: "Compress All",
            systemImage: LairConstants.Lair.compressZipActionIcon
        ) {
            compressAllItems(urls: resolvedURLs)
        }

        // Convert (if any images)
        let hasImages = items.contains(where: { $0.isImage })
        menu.addActionItem(
            title: LairConstants.Lair.convertActionText,
            systemImage: LairConstants.Lair.convertActionIcon,
            isEnabled: hasImages
        ) {
            onConvert()
        }

        menu.addItem(NSMenuItem.separator())

        // Remove the top artifact
        if let topItem = items.last {
            menu.addActionItem(
                title: LairConstants.Lair.removeFromLairActionText,
                systemImage: LairConstants.Lair.removeFromLairActionIcon
            ) { [store] in
                store.removeFile(id: topItem.id)
            }
        }

        // Clear Lair
        menu.addActionItem(
            title: LairConstants.Lair.clearActionText,
            systemImage: LairConstants.Lair.clearActionIcon
        ) { [store] in
            store.clearAll()
        }
    }

    // MARK: - Open With Submenu

    private func buildOpenWithSubmenu(menu: NSMenu, url: URL) {
        let openWithSubmenu = NSMenu()
        openWithSubmenu.autoenablesItems = false

        let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
        for appURL in apps {
            let appName = FileManager.default.displayName(atPath: appURL.path)
            let appIconImage = NSWorkspace.shared.icon(forFile: appURL.path)
            appIconImage.size = NSSize(width: 16, height: 16)

            let target = MenuActionTarget {
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
            }
            let appItem = NSMenuItem(
                title: appName,
                action: #selector(MenuActionTarget.performAction(_:)),
                keyEquivalent: ""
            )
            appItem.target = target
            appItem.representedObject = target
            appItem.image = appIconImage
            appItem.isEnabled = true
            openWithSubmenu.addItem(appItem)
        }

        if !apps.isEmpty {
            openWithSubmenu.addItem(NSMenuItem.separator())
        }

        openWithSubmenu.addActionItem(title: "Other…", systemImage: "ellipsis") {
            openWithOther(url: url)
        }

        menu.addSubmenuItem(
            title: LairConstants.Lair.openWithActionText,
            systemImage: LairConstants.Lair.openWithActionIcon,
            submenu: openWithSubmenu
        )
    }

    // MARK: - Quick Look

    private func quickLookItems(_ items: [FileItem]) {
        let urls = items.compactMap { $0.resolveURL() }
        guard !urls.isEmpty else { return }

        let panel = QLPreviewPanel.shared()!
        let delegate = QuickLookCoordinator(urls: urls)

        // Retain the coordinator for the lifetime of the panel session
        objc_setAssociatedObject(panel, "qlCoordinator", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        panel.dataSource = delegate
        panel.delegate = delegate

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    // MARK: - AirDrop

    private func airdropItems(urls: [URL]) {
        guard !urls.isEmpty else { return }
        guard let airdropService = NSSharingService(named: .sendViaAirDrop) else { return }

        NSApp.activate(ignoringOtherApps: true)
        airdropService.perform(withItems: urls)
    }

    // MARK: - Compress All Items

    private func compressAllItems(urls: [URL]) {
        guard !urls.isEmpty else { return }

        // Use the parent directory of the first item
        let baseDir = urls[0].deletingLastPathComponent()
        var destZipURL = baseDir.appendingPathComponent("Archive.zip")
        var counter = 1
        while FileManager.default.fileExists(atPath: destZipURL.path) {
            counter += 1
            destZipURL = baseDir.appendingPathComponent("Archive \(counter).zip")
        }

        // Create a temporary directory and copy/link all items into it
        Task.detached {
            do {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                for url in urls {
                    let dest = tempDir.appendingPathComponent(url.lastPathComponent)
                    try FileManager.default.copyItem(at: url, to: dest)
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--sequesterRsrc", tempDir.path, destZipURL.path]
                try process.run()
                process.waitUntilExit()

                // Clean up temp directory
                try? FileManager.default.removeItem(at: tempDir)

                if process.terminationStatus == 0 {
                    await MainActor.run { [store] in
                        store.addFile(url: destZipURL)
                    }
                } else {
                    await MainActor.run {
                        showErrorAlert(title: "Compression Failed", message: "Compression failed with exit code \(process.terminationStatus)")
                    }
                }
            } catch {
                await MainActor.run {
                    showErrorAlert(title: "Compression Failed", message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Helper Methods for Chevron Menu Actions
    
    private func appIcon(for path: String) -> Image {
        let nsImage = NSWorkspace.shared.icon(forFile: path)
        nsImage.size = NSSize(width: 16, height: 16)
        return Image(nsImage: nsImage)
    }
    
    private func isDirectory(url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func openInTerminal(url: URL) {
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

    private func renameItem(_ item: FileItem, url: URL) {
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

    private func duplicateItem(url: URL) {
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

    private func compressItem(url: URL) {
        let baseDir = url.deletingLastPathComponent()
        let nameWithoutExt = url.deletingPathExtension().lastPathComponent
        
        var destZipURL = baseDir.appendingPathComponent("\(nameWithoutExt).zip")
        var counter = 1
        while FileManager.default.fileExists(atPath: destZipURL.path) {
            counter += 1
            destZipURL = baseDir.appendingPathComponent("\(nameWithoutExt) \(counter).zip")
        }
        
        Task {
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

    private func openWithOther(url: URL) {
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application, .executable]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        
        NSApp.activate(ignoringOtherApps: true)
        if openPanel.runModal() == .OK, let appURL = openPanel.url {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
