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
        static let height: CGFloat = 300
        static let cornerRadius: CGFloat = 26
        
        // File Pile Position
        static let filePileX: CGFloat = 12
        static let filePileYStandard: CGFloat = 60
        static let filePileHeightStandard: CGFloat = 200
        
        static let filePileYConvertShown: CGFloat = 100 // Pushed to the top a little
        static let filePileHeightConvertShown: CGFloat = 164 // Adjusted to fit under the top bar
        
        // File Card Sizes
        static let fileItemStandardDimension: CGFloat = 100
        static let fileItemLargeDimension: CGFloat = 100 // Made a little bit bigger (was 100)
        static let fileItemCompactDimension: CGFloat = 80
        
        // Top Right Menu Configuration
        static let menuIconName = "chevron.down"
        static let clearActionText = "Clear Lair"
        static let clearActionIcon = "trash"
        
        // Button Opacity Configurations
        static let buttonBackgroundOpacity: Double = 0.3
        static let buttonBorderOpacity: Double = 0.3

        // Compact Mode Configuration
        static let compactWidth: CGFloat = 220
        static let compactHeight: CGFloat = 220
        static let filePileYCompact: CGFloat = 64
        static let filePileHeightCompact: CGFloat = 120
    }
    
    struct Convert {
        static let width: CGFloat = 350
        static let height: CGFloat = 436
        static let cornerRadius: CGFloat = 36 // Unified corner radius to resolve overlaps
        static let inputBorderWidth: CGFloat = 2 // Centralized input border weight
    }
}
