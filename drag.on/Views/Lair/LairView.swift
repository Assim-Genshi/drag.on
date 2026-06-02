import SwiftUI

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
                .fill(uiState.isExternalDragActive ? Color.cyanDream.opacity(LairConstants.Lair.dragActiveBgOpacity) : mainSurface.opacity(0.35))
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
        RoundedRectangle(cornerRadius: 14)
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
                    Menu {
                        if let topItem = store.items.last, let url = topItem.resolveURL() {
                            let isDir = isDirectory(url: url)
                            
                            if isDir {
                                Button(action: {
                                    NSWorkspace.shared.open(url)
                                }) {
                                    Label(LairConstants.Lair.openActionText, systemImage: LairConstants.Lair.openActionIcon)
                                }
                                
                                Button(action: {
                                    NSWorkspace.shared.open(url)
                                }) {
                                    Label(LairConstants.Lair.openInFinderActionText, systemImage: LairConstants.Lair.openInFinderActionIcon)
                                }
                                
                                Button(action: {
                                    openInTerminal(url: url)
                                }) {
                                    Label(LairConstants.Lair.openInTerminalActionText, systemImage: LairConstants.Lair.openInTerminalActionIcon)
                                }
                                
                                let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
                                Menu {
                                    ForEach(apps, id: \.self) { appURL in
                                        Button(action: {
                                            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
                                        }) {
                                            Label {
                                                Text(FileManager.default.displayName(atPath: appURL.path))
                                            } icon: {
                                                appIcon(for: appURL.path)
                                            }
                                        }
                                    }
                                    Divider()
                                    Button(action: {
                                        openWithOther(url: url)
                                    }) {
                                        Label("Other…", systemImage: "ellipsis")
                                    }
                                } label: {
                                    Label(LairConstants.Lair.openWithActionText, systemImage: LairConstants.Lair.openWithActionIcon)
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }) {
                                    Label(LairConstants.Lair.revealInFinderActionText, systemImage: LairConstants.Lair.revealInFinderActionIcon)
                                }
                                
                                Button(action: {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(url.path, forType: .string)
                                }) {
                                    Label(LairConstants.Lair.copyPathActionText, systemImage: LairConstants.Lair.copyPathActionIcon)
                                }
                                
                                Button(action: {
                                    renameItem(topItem, url: url)
                                }) {
                                    Label(LairConstants.Lair.renameActionText, systemImage: LairConstants.Lair.renameActionIcon)
                                }
                                
                                Button(action: {
                                    duplicateItem(url: url)
                                }) {
                                    Label(LairConstants.Lair.duplicateActionText, systemImage: LairConstants.Lair.duplicateActionIcon)
                                }
                                
                                Button(action: {
                                    compressItem(url: url)
                                }) {
                                    Label(LairConstants.Lair.compressZipActionText, systemImage: LairConstants.Lair.compressZipActionIcon)
                                }
                            } else {
                                Button(action: {
                                    NSWorkspace.shared.open(url)
                                }) {
                                    Label(LairConstants.Lair.openActionText, systemImage: LairConstants.Lair.openActionIcon)
                                }
                                
                                let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
                                Menu {
                                    ForEach(apps, id: \.self) { appURL in
                                        Button(action: {
                                            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
                                        }) {
                                            Label {
                                                Text(FileManager.default.displayName(atPath: appURL.path))
                                            } icon: {
                                                appIcon(for: appURL.path)
                                            }
                                        }
                                    }
                                    Divider()
                                    Button(action: {
                                        openWithOther(url: url)
                                    }) {
                                        Label("Other…", systemImage: "ellipsis")
                                    }
                                } label: {
                                    Label(LairConstants.Lair.openWithActionText, systemImage: LairConstants.Lair.openWithActionIcon)
                                }
                                
                                Button(action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }) {
                                    Label(LairConstants.Lair.revealInFinderActionText, systemImage: LairConstants.Lair.revealInFinderActionIcon)
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(url.path, forType: .string)
                                }) {
                                    Label(LairConstants.Lair.copyPathActionText, systemImage: LairConstants.Lair.copyPathActionIcon)
                                }
                                
                                Button(action: {
                                    renameItem(topItem, url: url)
                                }) {
                                    Label(LairConstants.Lair.renameActionText, systemImage: LairConstants.Lair.renameActionIcon)
                                }
                                
                                Button(action: {
                                    duplicateItem(url: url)
                                }) {
                                    Label(LairConstants.Lair.duplicateActionText, systemImage: LairConstants.Lair.duplicateActionIcon)
                                }
                                
                                Button(action: {
                                    compressItem(url: url)
                                }) {
                                    Label(LairConstants.Lair.compressZipActionText, systemImage: LairConstants.Lair.compressZipActionIcon)
                                }
                                
                                Button(action: onConvert) {
                                    Label {
                                        Text("✨ Convert…")
                                    } icon: {
                                        Image(systemName: "wand.and.stars.inverse")
                                    }
                                }
                                .disabled(!topItem.isImage)
                            }
                            
                            Divider()
                            
                            Button(action: {
                                store.removeFile(id: topItem.id)
                            }) {
                                Label(LairConstants.Lair.removeFromLairActionText, systemImage: LairConstants.Lair.removeFromLairActionIcon)
                            }
                        }
                        
                        Button(role: .destructive, action: {
                            store.clearAll()
                        }) {
                            Label(LairConstants.Lair.clearActionText, systemImage: LairConstants.Lair.clearActionIcon)
                        }
                    } label: {
                        LairCircleButton(systemName: LairConstants.Lair.menuIconName)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Helper Methods for Chevron Menu Actions
    
    private func appIcon(for path: String) -> Image {
        let nsImage = NSWorkspace.shared.icon(forFile: path)
        nsImage.size = NSSize(width: 16, height: 16)
        return Image(nsImage: nsImage).renderingMode(.original)
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
