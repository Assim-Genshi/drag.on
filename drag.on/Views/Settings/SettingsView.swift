import SwiftUI
import LaunchAtLogin
import KeyboardShortcuts

// MARK: - Keyboard Shortcut Names

extension KeyboardShortcuts.Name {
    static let toggleLair = Self("toggleLair", default: .init(.l, modifiers: [.option, .command]))
    static let openFromClipboard = Self("openFromClipboard", default: .init(.v, modifiers: [.option, .command]))
    static let previousLair = Self("previousLair", default: .init(.p, modifiers: [.option, .command]))
}

// MARK: - Window Accessor & Appearance Modifier

/// Helper view that provides access to the underlying NSWindow.
struct WindowAccessor: NSViewRepresentable {
    var onWindowLocated: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.onWindowLocated(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// A view modifier that controls the target window's NSAppearance name.
struct WindowAppearanceModifier: ViewModifier {
    var appearance: NSAppearance.Name?

    func body(content: Content) -> some View {
        content.background(
            WindowAccessor { window in
                if let appearance = self.appearance {
                    window?.appearance = NSAppearance(named: appearance)
                } else {
                    // Setting to nil tells the window to follow the system appearance again
                    window?.appearance = nil
                }
            }
        )
    }
}

extension View {
    func windowAppearance(_ appearance: NSAppearance.Name?) -> some View {
        self.modifier(WindowAppearanceModifier(appearance: appearance))
    }
}

// MARK: - Settings Window Configurator

/// Configures the Settings NSWindow for a chromeless, Arc-style frosted glass appearance.
struct SettingsWindowConfigurator: NSViewRepresentable {
    
    /// Adjust this value to shift the traffic light buttons horizontally.
    /// Positive values push them to the right, negative values to the left.
    let trafficLightXOffset: CGFloat = 7.0
    
    /// Adjust this value to push the traffic light buttons down.
    /// Positive values push them further down.
    let trafficLightYOffset: CGFloat = -7.0

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert([.fullSizeContentView, .miniaturizable])
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            
            // Remove the toolbar if it exists
            window.toolbar = nil
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            
            // Mask the entire window frame to perfectly match our 22pt corner radius.
            if let themeFrame = window.contentView?.superview {
                themeFrame.wantsLayer = true
                themeFrame.layer?.cornerRadius = 22
                themeFrame.layer?.masksToBounds = true
            }
            
            // Natively shift traffic light buttons down and sideways by adjusting their frames
            // This ensures both the visual button and its clickable hitbox stay perfectly in sync.
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                if let button = window.standardWindowButton(type) {
                    // Remove any visual-only translation
                    button.layer?.transform = CATransform3DIdentity
                    
                    // In AppKit titlebars (which are flipped), Y=0 is the top.
                    // If layer transform was CATransform3DMakeTranslation(x, y, 0), it behaved exactly the same.
                    // We detect if the system reset the frame by checking the X origin.
                    // Standard X origins: close=~12, miniaturize=~32, zoom=~52
                    let needsShift: Bool
                    switch type {
                    case .closeButton: needsShift = button.frame.origin.x < 15
                    case .miniaturizeButton: needsShift = button.frame.origin.x < 35
                    case .zoomButton: needsShift = button.frame.origin.x < 55
                    default: needsShift = false
                    }
                    
                    if needsShift {
                        button.setFrameOrigin(NSPoint(
                            x: button.frame.origin.x + trafficLightXOffset,
                            y: button.frame.origin.y + trafficLightYOffset
                        ))
                    }
                }
            }
        }
    }
}

// MARK: - SettingsView

/// Arc browser-style settings view with frosted glass background and content card.
struct SettingsView: View {
    @AppStorage("shakeSensitivity") private var shakeSensitivity: Double = 3.0
    @AppStorage("defaultFormat") private var defaultFormat: String = "WebP"
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("enableCloudAnimation") private var enableCloudAnimation: Bool = true
    @AppStorage("appTheme") private var appTheme: String = "System"
    @AppStorage("preferredTerminal") private var preferredTerminal: String = "Terminal.app"
    @AppStorage("webDropLocationPath") private var webDropLocationPath: String = ""
    @AppStorage("defaultOutputMode") private var defaultOutputMode: String = "sameFolder"
    @AppStorage("customOutputDirectoryPath") private var customOutputDirectoryPath: String = ""
    @AppStorage("summonPosition") private var summonPosition: String = "Above"
    @AppStorage("summonDistance") private var summonDistance: Double = 40.0

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Theme Colors (matching ConvertView)

    private var primaryTextColor: Color { Color("content-100") }
    private var surfeceColor: Color { Color("main-surfece") }
    private var secondaryTextColor: Color { Color("content-200") }
    private var accentColor: Color { Color("skyblue") }
    private var secondarysurfeceColor: Color { Color("Secondary-surfece") }
    private var cardBorder: Color { Color("border-color") }

    var body: some View {
        VStack(spacing: 0) {
            // Glassy top bar (sits over the material, above the card)
            ZStack {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                    Text("settings")
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40) // Top bar height

            // Content card
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: Header
                    headerBanner

                    Divider()

                    // MARK: Content
                    VStack(alignment: .leading, spacing: 0) {
                        generalSection

                        Divider().padding(.vertical, 16)

                        conversionSection

                        Divider().padding(.vertical, 16)

                        appearanceSection

                        Divider().padding(.vertical, 16)

                        shortcutsSection
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(surfeceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color("border-color"), lineWidth: 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 15, x: 0, y: 5)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .frame(width: 540, height: 540)
        .background(
            ZStack {
                Color.primary.opacity(0.05)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .ignoresSafeArea(.all)
        .preferredColorScheme(colorSchemeForTheme)
        .windowAppearance(windowAppearance)
        .background(SettingsWindowConfigurator())
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        ZStack {
            // Background fill + optional sky image
            ZStack {
                surfeceColor

                    Image("sky_clouds_bg")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .overlay(Color.black.opacity(0.2))
                        
            }

            // Centered App Icon + App Name and Version info
            HStack(spacing: 16) {
                Image("appIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Drag.on")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Version 1.0 beta")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.black.opacity(0.4))
                        .opacity(0.6)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .clipped()
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("General")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(primaryTextColor)

            row(title: "Launch At Login", subtitle: "Start Drag.on when you log in") {
                LaunchAtLogin.Toggle("")
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            row(title: "Terminal", subtitle: "App to open folders in") {
                menuInput(icon: "terminal", text: preferredTerminal) {
                    Button("Terminal.app") { preferredTerminal = "Terminal.app" }
                    Button("iTerm2") { preferredTerminal = "iTerm2" }
                    Button("Warp") { preferredTerminal = "Warp" }
                }
            }

            row(title: "Web Drops Location", subtitle: "Where web drops are saved") {
                Button(action: selectDownloadLocation) {
                    SelectorInputLabel(downloadLocationDisplayName, showChevron: false, hasShadow: true) {
                        FolderIconPreviewView(url: webDropLocationURL)
                    }
                }
                .buttonStyle(.plain)
                .fixedSize()
                .pointerCursor()
            }

            row(title: "Shake Sensitivity", subtitle: "Reversals needed to summon Lair") {
                HStack(spacing: 8) {
                    Slider(value: $shakeSensitivity, in: 2...5, step: 1)
                        .frame(width: 80)
                    Text("\(Int(shakeSensitivity))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                }
            }

            row(title: "Summon Position", subtitle: "Where Lair appears relative to cursor") {
                menuInput(icon: "cursorarrow", text: summonPositionDisplayName) {
                    Button("Above Cursor") { summonPosition = "Above" }
                    Button("Below Cursor") { summonPosition = "Below" }
                    Button("Left of Cursor") { summonPosition = "Left" }
                    Button("Right of Cursor") { summonPosition = "Right" }
                }
            }

            row(title: "Summon Distance", subtitle: "Gap between cursor and Lair") {
                menuInput(icon: "arrow.up.and.down", text: summonDistanceDisplayName) {
                    Button("Small") { summonDistance = 20.0 }
                    Button("Medium") { summonDistance = 40.0 }
                    Button("Large") { summonDistance = 70.0 }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Conversion Section

    private var conversionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conversion")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(primaryTextColor)

            row(title: "Default Format", subtitle: "Pre-selected format in converter") {
                menuInput(icon: "doc.badge.gearshape", text: defaultFormat) {
                    ForEach(ImageFormat.allCases) { format in
                        Button(format.rawValue) { defaultFormat = format.rawValue }
                    }
                }
            }

            row(title: "Default Output", subtitle: "Where converted files are saved") {
                menuInput(text: defaultOutputDisplayName) {
                    Group {
                        switch defaultOutputMode {
                        case "downloads":
                            SelectorIcon(systemImage: "arrow.down.circle", color: accentColor)
                        case "custom":
                            if let url = customOutputURL {
                                FolderIconPreviewView(url: url)
                            } else {
                                SelectorIcon(systemImage: "folder.badge.questionmark", color: accentColor)
                            }
                        default: // "sameFolder"
                            SelectorIcon(systemImage: "folder", color: accentColor)
                        }
                    }
                } items: {
                    Button("Same Folder") {
                        defaultOutputMode = "sameFolder"
                    }
                    Button("Downloads") {
                        defaultOutputMode = "downloads"
                    }
                    Button("Custom Folder...") {
                        selectCustomOutputLocation()
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(primaryTextColor)

            row(title: "Compact Mode", subtitle: "Smaller Lair window") {
                Toggle("", isOn: $compactMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            row(title: "Cloud Animation", subtitle: "Show cloud puff when clearing the Lair") {
                Toggle("", isOn: $enableCloudAnimation)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            row(title: "App Theme", subtitle: "Select window color appearance") {
                HStack(spacing: 8) {
                    themeCard(imageName: "auto mode", themeValue: "System")
                    themeCard(imageName: "light mede", themeValue: "Light")
                    themeCard(imageName: "dark mode", themeValue: "Dark")
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shortcuts")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(primaryTextColor)

            ShortcutSettingRow(
                title: "Toggle Lair",
                subtitle: "Show or hide the Lair window",
                shortcutName: .toggleLair
            )

            ShortcutSettingRow(
                title: "Open from Clipboard",
                subtitle: "Open Lair with clipboard content",
                shortcutName: .openFromClipboard
            )

            ShortcutSettingRow(
                title: "Previous Lair",
                subtitle: "Restore items from the previous Lair",
                shortcutName: .previousLair
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Window Appearance

    private var windowAppearance: NSAppearance.Name? {
        switch appTheme {
        case "Light":
            return .aqua
        case "Dark":
            return .darkAqua
        default: // "System"
            return nil
        }
    }

    private var colorSchemeForTheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    // MARK: - Row Helper

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(primaryTextColor)
    }

    private func row<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primaryTextColor.opacity(0.85))

                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.leading, 2)
            }

            Spacer()

            content()
        }
    }
    
    // MARK: - Theme Card

    /// A selectable theme card with a preview image and title.
    private func themeCard(imageName: String, themeValue: String) -> some View {
        let isSelected = appTheme == themeValue

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appTheme = themeValue
            }
        } label: {
            VStack(spacing: 4) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color("skyblue") : secondarysurfeceColor.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    // MARK: - Input Helpers

    /// Reusable menu input (icon + text + chevron + menu items) with thinMaterial and top highlight.
    private func menuInput<Items: View>(icon: String, text: String, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            items()
        } label: {
            SelectorInputLabel(text, systemImage: icon, hasShadow: true, accentColor: accentColor)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .pointerCursor()
    }

    /// Reusable menu input with custom start content (icon/preview + text + chevron + menu items) with thinMaterial and top highlight.
    private func menuInput<StartContent: View, Items: View>(
        text: String,
        @ViewBuilder startContent: () -> StartContent,
        @ViewBuilder items: () -> Items
    ) -> some View {
        Menu {
            items()
        } label: {
            SelectorInputLabel(text, showChevron: true, hasShadow: true, accentColor: accentColor) {
                startContent()
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .pointerCursor()
    }

    // MARK: - Computed Properties

    private var summonPositionDisplayName: String {
        switch summonPosition {
        case "Above": return "Above Cursor"
        case "Below": return "Below Cursor"
        case "Left": return "Left of Cursor"
        case "Right": return "Right of Cursor"
        default: return "Above Cursor"
        }
    }

    private var summonDistanceDisplayName: String {
        switch summonDistance {
        case ..<30.0: return "Small"
        case 30.0..<60.0: return "Medium"
        default: return "Large"
        }
    }

    private var downloadLocationDisplayName: String {
        if webDropLocationPath.isEmpty {
            return "Downloads"
        }
        let url = URL(fileURLWithPath: webDropLocationPath)
        return url.lastPathComponent
    }

    private var webDropLocationURL: URL {
        if webDropLocationPath.isEmpty {
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        }
        return URL(fileURLWithPath: webDropLocationPath)
    }

    private var defaultOutputDisplayName: String {
        switch defaultOutputMode {
        case "downloads":
            return "Downloads"
        case "custom":
            if customOutputDirectoryPath.isEmpty {
                return "Choose Folder..."
            }
            let url = URL(fileURLWithPath: customOutputDirectoryPath)
            return url.lastPathComponent
        default: // "sameFolder"
            return "Same Folder"
        }
    }

    private var customOutputURL: URL? {
        if customOutputDirectoryPath.isEmpty {
            return nil
        }
        return URL(fileURLWithPath: customOutputDirectoryPath)
    }

    private func selectCustomOutputLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Location"

        if panel.runModal() == .OK, let url = panel.url {
            customOutputDirectoryPath = url.path
            defaultOutputMode = "custom"
        }
    }

    // MARK: - Actions

    private func selectDownloadLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Location"

        if panel.runModal() == .OK, let url = panel.url {
            webDropLocationPath = url.path
        }
    }
}

// MARK: - Shortcut Setting Row

struct ShortcutSettingRow: View {
    let title: String
    let subtitle: String
    let shortcutName: KeyboardShortcuts.Name

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color("content-100").opacity(0.85))

                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(Color("content-200"))
                    .padding(.leading, 2)
            }

            Spacer()

            CustomShortcutRecorder(name: shortcutName)
        }
    }
}

// MARK: - Custom Shortcut Recorder

struct CustomShortcutRecorder: View {
    let name: KeyboardShortcuts.Name
    @State private var shortcut: KeyboardShortcuts.Shortcut?
    @State private var isRecording = false
    @State private var recordingModifiers: NSEvent.ModifierFlags = []
    @State private var monitor: Any? = nil
    @State private var resignObserver: Any? = nil
    
    private var accentColor: Color { Color("skyblue") }
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            if isRecording {
                HStack(spacing: 6) {
                    if !recordingModifiersList.isEmpty {
                        ForEach(recordingModifiersList, id: \.self) { mod in
                            KeyCapView(text: mod, isActive: true)
                            Text("+")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color("content-200"))
                        }
                    }
                    Text("Press keys...")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(accentColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1.0)
                        )
                }
            } else if shortcut != nil {
                HStack(spacing: 6) {
                    let mods = modifiersList
                    ForEach(mods, id: \.self) { mod in
                        KeyCapView(text: mod)
                        Text("+")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color("content-200"))
                    }
                    KeyCapView(text: keyLabel)
                }
            } else {
                Text("Click to Record")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("content-200"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color("Secondary-surfece"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color("border-color"), lineWidth: 1.0)
                    )
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onAppear {
            self.shortcut = KeyboardShortcuts.getShortcut(for: name)
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private var modifiersList: [String] {
        guard let shortcut = shortcut else { return [] }
        var list: [String] = []
        let mods = shortcut.modifiers
        if mods.contains(.control) { list.append("^") }
        if mods.contains(.option) { list.append("⌥") }
        if mods.contains(.shift) { list.append("⇧") }
        if mods.contains(.command) { list.append("⌘") }
        return list
    }
    
    private var recordingModifiersList: [String] {
        var list: [String] = []
        if recordingModifiers.contains(.control) { list.append("^") }
        if recordingModifiers.contains(.option) { list.append("⌥") }
        if recordingModifiers.contains(.shift) { list.append("⇧") }
        if recordingModifiers.contains(.command) { list.append("⌘") }
        return list
    }
    
    private var keyLabel: String {
        guard let shortcut = shortcut else { return "" }
        var desc = shortcut.description
        for char in ["⌃", "⌥", "⇧", "⌘"] {
            desc = desc.replacingOccurrences(of: char, with: "")
        }
        if desc.lowercased() == "space" {
            return "Space"
        }
        return desc
    }
    
    private func startRecording() {
        isRecording = true
        recordingModifiers = []
        
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                self.stopRecording()
            }
        }
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                var flags = NSEvent.ModifierFlags()
                if event.modifierFlags.contains(.control) { flags.insert(.control) }
                if event.modifierFlags.contains(.option) { flags.insert(.option) }
                if event.modifierFlags.contains(.shift) { flags.insert(.shift) }
                if event.modifierFlags.contains(.command) { flags.insert(.command) }
                self.recordingModifiers = flags
                return nil
            } else if event.type == .keyDown {
                let key = KeyboardShortcuts.Key(rawValue: Int(event.keyCode))
                if key == .escape {
                    stopRecording()
                    return nil
                }
                if key == .delete || key == .deleteForward {
                    KeyboardShortcuts.setShortcut(nil, for: name)
                    self.shortcut = nil
                    stopRecording()
                    return nil
                }
                
                let hasModifier = !recordingModifiers.isEmpty
                let isFunctionKey = self.isFunctionKey(key)
                
                if hasModifier || isFunctionKey {
                    let newShortcut = KeyboardShortcuts.Shortcut(key, modifiers: recordingModifiers)
                    KeyboardShortcuts.setShortcut(newShortcut, for: name)
                    self.shortcut = newShortcut
                    stopRecording()
                }
                return nil
            }
            return event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let observer = resignObserver {
            NotificationCenter.default.removeObserver(observer)
            self.resignObserver = nil
        }
    }
    
    private func isFunctionKey(_ key: KeyboardShortcuts.Key) -> Bool {
        let fKeys: Set<Int> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
        return fKeys.contains(key.rawValue)
    }
}

// MARK: - KeyCapView

struct KeyCapView: View {
    let text: String
    var isActive: Bool = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isActive ? Color("skyblue") : Color("content-100"))
            .frame(minWidth: 32, minHeight: 32)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color("main-surfece"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isActive ? Color("skyblue").opacity(0.6) : Color("border-color"), lineWidth: 1.0)
            )
            .shadow(color: .black.opacity(isActive ? 0.08 : 0.04), radius: 1.5, x: 0, y: 1)
    }
}
