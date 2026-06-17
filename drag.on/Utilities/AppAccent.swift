import SwiftUI

// MARK: - Accent Theme

/// Defines the available accent color themes for the application.
/// Each theme maps to a pair of color assets in the asset catalog: `<theme>-1` (main) and `<theme>-2` (secondary).
enum AccentTheme: String, CaseIterable, Identifiable {
    case hydro
    case pyro
    case dendro
    case geo
    case cryo
    case luxis

    var id: String { rawValue }

    /// Human-readable display name for the theme.
    var displayName: String {
        switch self {
        case .hydro:  return "Hydro"
        case .pyro:   return "Pyro"
        case .dendro: return "Dendro"
        case .geo:    return "Geo"
        case .cryo:   return "Cryo"
        case .luxis:  return "Luxis"
        }
    }

    /// The element that this theme represents.
    var elementName: String {
        switch self {
        case .hydro:  return "Water"
        case .pyro:   return "Fire"
        case .dendro: return "Nature"
        case .geo:    return "Earth"
        case .cryo:   return "Ice"
        case .luxis:  return "Light"
        }
    }

    /// SF Symbol icon representing this element.
    var iconName: String {
        switch self {
        case .hydro:  return "drop.fill"
        case .pyro:   return "flame.fill"
        case .dendro: return "leaf.fill"
        case .geo:    return "mountain.2.fill"
        case .cryo:   return "snowflake"
        case .luxis:  return "sparkles"
        }
    }

    /// The name of the custom element icon asset.
    var customIconName: String {
        switch self {
        case .hydro:  return "hydro"
        case .pyro:   return "pyro"
        case .dendro: return "dendro"
        case .geo:    return "geo"
        case .cryo:   return "cryo"
        case .luxis:  return "luxis"
        }
    }

    // MARK: Asset Color Names

    /// The asset catalog name for this theme's main (primary) color.
    var mainColorName: String { "\(rawValue)-1" }

    /// The asset catalog name for this theme's secondary (lighter) color.
    var secondaryColorName: String { "\(rawValue)-2" }

    // MARK: Resolved Colors

    /// The main accent color for this theme.
    var mainColor: Color { Color(mainColorName) }

    /// The secondary accent color for this theme.
    var secondaryColor: Color { Color(secondaryColorName) }
}

// MARK: - Accent Variant

/// Selects between the main or secondary accent color.
enum AccentVariant {
    case main
    case secondary
}

// MARK: - AppAccent Property Wrapper

/// A reactive property wrapper that resolves the current accent color based on the user's selected theme.
///
/// Usage:
/// ```swift
/// @AppAccent(.main) private var mainAccent
/// @AppAccent(.secondary) private var secondaryAccent
/// ```
///
/// The wrapper observes `UserDefaults` for the key `"accentTheme"` and automatically
/// triggers a SwiftUI view update whenever the theme changes.
@propertyWrapper
struct AppAccent: DynamicProperty {
    @AppStorage("accentTheme") private var themeRawValue: String = AccentTheme.hydro.rawValue

    private let variant: AccentVariant

    init(_ variant: AccentVariant = .main) {
        self.variant = variant
    }

    var wrappedValue: Color {
        let theme = AccentTheme(rawValue: themeRawValue) ?? .hydro
        switch variant {
        case .main:
            return theme.mainColor
        case .secondary:
            return theme.secondaryColor
        }
    }
}

// MARK: - Color Convenience Extensions

extension Color {
    /// The currently active main accent color (non-reactive, reads from UserDefaults directly).
    /// Use `@AppAccent(.main)` for reactive updates inside SwiftUI views.
    static var mainAccent: Color {
        let rawValue = UserDefaults.standard.string(forKey: "accentTheme") ?? AccentTheme.hydro.rawValue
        let theme = AccentTheme(rawValue: rawValue) ?? .hydro
        return theme.mainColor
    }

    /// The currently active secondary accent color (non-reactive, reads from UserDefaults directly).
    /// Use `@AppAccent(.secondary)` for reactive updates inside SwiftUI views.
    static var secondaryAccent: Color {
        let rawValue = UserDefaults.standard.string(forKey: "accentTheme") ?? AccentTheme.hydro.rawValue
        let theme = AccentTheme(rawValue: rawValue) ?? .hydro
        return theme.secondaryColor
    }
}
