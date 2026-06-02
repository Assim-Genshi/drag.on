import SwiftUI
import ServiceManagement

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
            // This prevents the native 10pt window corners and top highlight from sticking out.
            if let themeFrame = window.contentView?.superview {
                themeFrame.wantsLayer = true
                themeFrame.layer?.cornerRadius = 22
                themeFrame.layer?.masksToBounds = true
            }
            
            // Natively shift traffic light buttons down and sideways without moving the window highlight
            // by only translating the individual buttons, not the entire container
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                if let button = window.standardWindowButton(type) {
                    button.wantsLayer = true
                    button.layer?.transform = CATransform3DMakeTranslation(trafficLightXOffset, trafficLightYOffset, 0)
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
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("appTheme") private var appTheme: String = "System"
    @AppStorage("preferredTerminal") private var preferredTerminal: String = "Terminal.app"
    @AppStorage("webDropLocationPath") private var webDropLocationPath: String = ""

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
                VStack(spacing: 12) {
                    Spacer()
                    HStack {
                    VStack(spacing: 4) {
                        Spacer()
                            .frame(height: 80)
                        
                        Text("Version 0.1 beta")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.white)
                            .padding(.bottom, 18)
                            .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 0)
                    }
                        Spacer()
                    }
                    .background(
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: LairConstants.Convert.cornerRadius)
                                .fill((surfeceColor).opacity(60))
                            if colorScheme != .dark {
                                Image("sky_clouds_bg")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 540, height: 380)
                                    .clipped()
                                    .mask(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.black, .black, .black.opacity(0.8), .clear]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .opacity(0.85)
                            }
                        }
                    )

                    // --- GENERAL ---
                    sectionHeader("GENERAL")
                    
                        row(title: "Launch At Login", subtitle: "Start Drag.on when you log in") {
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .onChange(of: launchAtLogin) { _, newValue in
                                    updateLoginItem(enabled: newValue)
                                }
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
                                inputLabel(icon: "folder", text: downloadLocationDisplayName)
                            }
                            .buttonStyle(.plain)
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
                    
                    Divider().padding(.vertical, 4)

                    // --- CONVERSION ---
                    sectionHeader("CONVERSION")

                    row(title: "Default Format", subtitle: "Pre-selected format in converter") {
                        menuInput(icon: "doc.badge.gearshape", text: defaultFormat) {
                            ForEach(ImageFormat.allCases) { format in
                                Button(format.rawValue) { defaultFormat = format.rawValue }
                            }
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // --- APPEARANCE ---
                    sectionHeader("APPEARANCE")

                    row(title: "Compact Mode", subtitle: "Smaller Lair window") {
                        Toggle("", isOn: $compactMode)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    // Theme picker cards
                    HStack(spacing: 8) {
                        themeCard(title: "System", imageName: "auto mode", themeValue: "System")
                        themeCard(title: "Light", imageName: "light mede", themeValue: "Light")
                        themeCard(title: "Dark", imageName: "dark mode", themeValue: "Dark")
                    }
                }
                .padding(16)
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
        .frame(width: 540, height: 470)
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

    // MARK: - Row Helpers

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(primaryTextColor.opacity(0.85))
                .tracking(1.0)
            Spacer()
        }
        .padding(.bottom, 4)
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
    
    // MARK: theme card
    /// A selectable theme card with a preview image and title.
    private func themeCard(title: String, imageName: String, themeValue: String) -> some View {
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
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : primaryTextColor)
            }
            .padding(4)
            .frame(maxWidth: .infinity)
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

    /// Reusable styled input label (icon + text + chevron) matching ConvertView inputs.
    private func inputLabel(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(accentColor)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(primaryTextColor)
            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .foregroundStyle(secondaryTextColor)
        }
        .padding(.horizontal, 12)
        .frame(height: LairConstants.Convert.inputHeight)
        .background(RoundedRectangle(cornerRadius: 10).fill(surfeceColor))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(cardBorder, lineWidth: LairConstants.Convert.inputBorderWidth))
    }

    /// Reusable menu input (icon + text + chevron + menu items) matching ConvertView inputs.
    private func menuInput<Items: View>(icon: String, text: String, @ViewBuilder items: () -> Items) -> some View {
        Menu {
            items()
        } label: {
            inputLabel(icon: icon, text: text)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .pointerCursor()
    }

    // MARK: - Helpers

    private func updateLoginItem(enabled: Bool) {
        if #available(macOS 16, *) {
            // Future: use SMAppService for macOS 16+
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently handle — login item registration may fail without proper entitlement
        }
    }

    private var downloadLocationDisplayName: String {
        if webDropLocationPath.isEmpty {
            return "Downloads"
        }
        let url = URL(fileURLWithPath: webDropLocationPath)
        return url.lastPathComponent
    }

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
