import Foundation
import Cocoa

/// Supported image conversion output formats.
enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case webp = "WebP"
    case png  = "PNG"
    case jpg  = "JPG"
    case icns = "ICNS"
    case ico  = "ICO"
    case pdf  = "PDF"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .webp: return "webp"
        case .png:  return "png"
        case .jpg:  return "jpg"
        case .icns: return "icns"
        case .ico:  return "ico"
        case .pdf:  return "pdf"
        }
    }

    /// Whether this format supports a quality slider (lossy formats only).
    var supportsQuality: Bool {
        switch self {
        case .webp, .jpg: return true
        default: return false
        }
    }

    /// Human-readable description for the format picker.
    var formatDescription: String {
        switch self {
        case .webp: return "Modern web format with excellent compression"
        case .png:  return "Lossless format with transparency support"
        case .jpg:  return "Universal photo format, smaller files"
        case .icns: return "Apple icon package for macOS apps"
        case .ico:  return "Windows icon format, multi-size"
        case .pdf:  return "Document format, vector-preserving"
        }
    }
}

struct LairConstants {
    struct Lair {
        static let width: CGFloat = 260
        static let height: CGFloat = 280
        static let cornerRadius: CGFloat = 34
        
        // File Pile Position
        static let filePileX: CGFloat = 12
        static let filePileYStandard: CGFloat = 60
        static let filePileHeightStandard: CGFloat = 200
        
        static let filePileYConvertShown: CGFloat = 86 // Pushed to the top a little
        static let filePileHeightConvertShown: CGFloat = 164 // Adjusted to fit under the top bar
        
        // File Card Sizes
        static let fileItemStandardDimension: CGFloat = 100
        static let fileItemLargeDimension: CGFloat = 100 // Made a little bit bigger (was 100)
        static let fileItemCompactDimension: CGFloat = 80
        
        // Top Right Menu Configuration
        static let menuIconName = "chevron.down"
        static let clearActionText = "Clear Lair"
        static let clearActionIcon = "delete.backward"
        
        // Context Menu Action Configuration
        static let openActionText = "Open"
        static let openActionIcon = "arrow.up.right.square"
        
        static let openWithActionText = "Open With"
        static let openWithActionIcon = "arrow.up.right.circle"
        
        static let revealInFinderActionText = "Reveal in Finder"
        static let revealInFinderActionIcon = "magnifyingglass"
        
        static let copyPathActionText = "Copy Path"
        static let copyPathActionIcon = "doc.on.doc"
        
        static let renameActionText = "Rename…"
        static let renameActionIcon = "pencil"
        
        static let duplicateActionText = "Duplicate"
        static let duplicateActionIcon = "plus.square.on.square"
        
        static let compressZipActionText = "Compress ZIP"
        static let compressZipActionIcon = "archivebox"
        
        static let convertActionText = "Convert…"
        static let convertActionIcon = "sparkle"
        
        static let openInTerminalActionText = "Open in Terminal"
        static let openInTerminalActionIcon = "terminal"
        
        static let openInFinderActionText = "Open in Finder"
        static let openInFinderActionIcon = "folder"
        
        static let removeFromLairActionText = "Remove the top artifact"
        static let removeFromLairActionIcon = "minus.circle"
        
        // Button Opacity Configurations
        static let buttonBackgroundOpacity: Double = 0.3
        static let buttonBorderOpacity: Double = 1
        
        // Drag Active Animations Configuration
        static let dragActiveBgOpacity: Double = 0.35
        static let dragActiveBorderWidth: CGFloat = 4.0
        static let dragInactiveBorderWidth: CGFloat = 2.0

        // Compact Mode Configuration
        static let compactWidth: CGFloat = 220
        static let compactHeight: CGFloat = 220
        static let filePileYCompact: CGFloat = 64
        static let filePileHeightCompact: CGFloat = 120

        // Management Panel Configuration
        static let managementWidth: CGFloat = 520
        static let managementHeight: CGFloat = 300
    }
    
    struct Convert {
        static let width: CGFloat = 380
        static let height: CGFloat = 480
        static let cornerRadius: CGFloat = 36 // Unified corner radius to resolve overlaps
        static let inputBorderWidth: CGFloat = 1 // Centralized input border weight
        static let inputHeight: CGFloat = 42 // Centralized input field height
    }
}

// MARK: - SwiftUI Helpers & View Modifiers

import SwiftUI

/// A view modifier that applies a premium top highlight border to a rounded rectangle shape.
struct TopHighlightBorder: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                colorScheme == .light
                                ? Color.white.opacity(0.6)
                                : Color.white.opacity(0.12),  // bright top highlight
                                Color.clear,
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: colorScheme == .dark ? 1 : lineWidth
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
    }
}

extension View {
    /// Applies a premium top highlight border using a gradient, useful for card/input designs.
    func topHighlightBorder(cornerRadius: CGFloat = 10, lineWidth: CGFloat = 2) -> some View {
        modifier(TopHighlightBorder(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}

