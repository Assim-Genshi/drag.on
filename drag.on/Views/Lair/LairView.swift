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
            }

            if uiState.isManagementPanelActive {
                managementPanelContent
            } else {
                mainLairContent

                topBar
            }
        }
        .background(
            RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius)
                .fill(mainSurface.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius)
                .stroke(borderColor, lineWidth: LairConstants.Convert.inputBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: LairConstants.Lair.cornerRadius))
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
                borderColor,
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
                        .foregroundStyle(content200)
                    Text("Drop Artifact here")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(content200)
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
                withAnimation(.easeInOut(duration: 0.2)) {
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
                            .foregroundStyle(content100)
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
                LairCircleButton(systemName: "xmark", action: onClose)

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
                                    Label("Compress", systemImage: LairConstants.Lair.compressZipActionIcon)
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
                                            Text(FileManager.default.displayName(atPath: appURL.path))
                                        }
                                    }
                                    Divider()
                                    Button("Other…") {
                                        openWithOther(url: url)
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
                                    Label(LairConstants.Lair.convertActionText, systemImage: LairConstants.Lair.convertActionIcon)
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

    // MARK: - Management Panel Content

    private var selectedItems: [FileItem] {
        store.items.filter { uiState.selectedItemIDs.contains($0.id) }
    }

    private var selectedImages: [FileItem] {
        selectedItems.filter(\.isImage)
    }

    private var managementPanelContent: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                LairCircleButton(systemName: "chevron.left", action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        uiState.isManagementPanelActive = false
                    }
                })
                .pointerCursor()
                
                Spacer()
                
                Text(uiState.selectedItemIDs.isEmpty ? "Lair Manager" : "\(uiState.selectedItemIDs.count) Selected")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(content100)
                
                Spacer()
                
                LairCircleButton(systemName: "xmark", action: onClose)
                .pointerCursor()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Scrollable Grid of file items
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 95, maximum: 110), spacing: 10)
                ], spacing: 10) {
                    ForEach(store.items) { item in
                        FileGridCell(
                            item: item,
                            store: store,
                            isSelected: uiState.selectedItemIDs.contains(item.id),
                            onSelectToggle: {
                                if uiState.selectedItemIDs.contains(item.id) {
                                    uiState.selectedItemIDs.remove(item.id)
                                } else {
                                    uiState.selectedItemIDs.insert(item.id)
                                }
                            },
                            getSelectedItems: {
                                selectedItems
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            
            Spacer(minLength: 8)
            
            // Floating management action bar
            managementActionBar
                .padding(.bottom, 14)
        }
    }

    private var managementActionBar: some View {
        HStack(spacing: 10) {
            if uiState.selectedItemIDs.isEmpty {
                Text("Select items to perform batch actions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(content200)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            } else {
                Spacer()

                ManagementButton(
                    icon: Image(systemName: "minus.circle"),
                    text: "Deselect",
                    color: content100,
                    action: {
                        uiState.selectedItemIDs.removeAll()
                    }
                )
                .pointerCursor()

                ManagementButton(
                    icon: Image(systemName: "arrow.up.right.square"),
                    text: "Open",
                    color: content100,
                    action: {
                        for item in selectedItems {
                            if let url = item.resolveURL() {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                )
                .pointerCursor()

                ManagementButton(
                    icon: Image(systemName: "magnifyingglass"),
                    text: "Reveal",
                    color: content100,
                    action: {
                        let urls = selectedItems.compactMap { $0.resolveURL() }
                        if !urls.isEmpty {
                            NSWorkspace.shared.activateFileViewerSelecting(urls)
                        }
                    }
                )
                .pointerCursor()

                if !selectedImages.isEmpty {
                    ManagementButton(
                        icon: WandIcon(size: 11, weight: .bold),
                        text: "Convert",
                        color: .blue,
                        action: {
                            onConvertSelected(selectedItems)
                        }
                    )
                    .pointerCursor()
                }

                ManagementButton(
                    icon: Image(systemName: "trash"),
                    text: "Delete",
                    color: .red,
                    action: {
                        for id in uiState.selectedItemIDs {
                            store.removeFile(id: id)
                        }
                        uiState.selectedItemIDs.removeAll()
                    }
                )
                .pointerCursor()

                Spacer()
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - File Grid Cell

struct FileGridCell: View {
    let item: FileItem
    let store: LairStore
    let isSelected: Bool
    let onSelectToggle: () -> Void
    let getSelectedItems: () -> [FileItem]

    @State private var isHovered = false
    @State private var thumbnail: NSImage? = nil

    private var content100: Color {
        Color("content-100")
    }

    private var content200: Color {
        Color("content-200")
    }

    private var borderColor: Color {
        Color("border-color")
    }

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                ZStack {
                    if let img = thumbnail {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    } else {
                        Image(nsImage: item.placeholderImage())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                    }
                }
                .frame(width: 54, height: 54)

                Text(item.fileName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(content100)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white.opacity(0.24) : Color.clear, lineWidth: 1.0)
            )

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.blue : content200.opacity(0.4))
                        .padding(6)
                }
                Spacer()
            }

            DragSourceHelper(
                item: item,
                store: store,
                isSelected: isSelected,
                onSelectToggle: onSelectToggle,
                onHoverToggle: { hover in
                    self.isHovered = hover
                },
                getSelectedItems: getSelectedItems
            )
        }
        .frame(height: 94)
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        Task { @MainActor in
            let img = await item.thumbnailAsync()
            self.thumbnail = img
        }
    }
}

// MARK: - Management Button

struct ManagementButton<Icon: View>: View {
    let icon: Icon
    let text: String
    let color: Color
    let action: () -> Void

    @State private var isHovering = false

    private var content100: Color {
        Color("content-100")
    }

    private var borderColor: Color {
        Color("border-color")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                icon
                Text(text)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(isHovering ? color : content100.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color("Secondary-surfece").opacity(LairConstants.Lair.buttonBackgroundOpacity))
            )
            .overlay(
                Capsule()
                    .stroke(borderColor.opacity(LairConstants.Lair.buttonBorderOpacity), lineWidth: 1.0)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.15 : 1.0)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = h
            }
        }
    }
}

// MARK: - File Count Label

struct FileCountLabel: View {
    let items: [FileItem]

    var body: some View {
        HStack(spacing: 4) {
            Text(countText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color("content-100"))
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color("content-100"))
        }
        .frame(height: 32)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color("Secondary-surfece").opacity(LairConstants.Lair.buttonBackgroundOpacity))
        )
        .overlay(
            Capsule()
                .stroke(Color("border-color").opacity(LairConstants.Lair.buttonBorderOpacity), lineWidth: 1.0)
        )
    }

    private var countText: String {
        let count = items.count
        if count == 1 {
            return "1 File"
        }
        let allImages = items.allSatisfy { SupportedImageExtensions.isImage(fileName: $0.fileName) }
        return allImages ? "\(count) Images" : "\(count) Files"
    }
}
