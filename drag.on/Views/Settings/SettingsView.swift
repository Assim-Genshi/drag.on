import SwiftUI
import ServiceManagement

/// App settings view displayed in the native macOS Settings window.
struct SettingsView: View {
    @AppStorage("shakeSensitivity") private var shakeSensitivity: Double = 3.0
    @AppStorage("defaultFormat") private var defaultFormat: String = "WebP"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("compactMode") private var compactMode: Bool = false
    @AppStorage("appTheme") private var appTheme: String = "System"

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            conversionTab
                .tabItem {
                    Label("Conversion", systemImage: "wand.and.rays")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 280)
        .preferredColorScheme(colorSchemeForTheme)
    }

    private var colorSchemeForTheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLoginItem(enabled: newValue)
                    }
            }

            Section("Shake Gesture") {
                HStack {
                    Text("Sensitivity")
                    Slider(value: $shakeSensitivity, in: 2...5, step: 1) {
                        Text("Reversals required")
                    }
                    Text("\(Int(shakeSensitivity))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            Section("Window Layout") {
                Toggle("Compact Mode", isOn: $compactMode)
            }

            Section("Theme") {
                Picker("App Theme", selection: $appTheme) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Conversion

    private var conversionTab: some View {
        Form {
            Section("Defaults") {
                Picker("Default Format", selection: $defaultFormat) {
                    ForEach(ImageFormat.allCases) { format in
                        Text(format.rawValue).tag(format.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "flame.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Drag.on")
                .font(.system(size: 20, weight: .bold))

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("A drop zone for your files.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Login Item

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
}
