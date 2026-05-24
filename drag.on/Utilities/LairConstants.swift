import Foundation
import Cocoa

/// Supported image conversion formats.
enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case webp = "WebP"
    case icns = "ICNS"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .webp: return "webp"
        case .icns: return "icns"
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
        static let filePileYCompact: CGFloat = 52
        static let filePileHeightCompact: CGFloat = 120
    }
    
    struct Convert {
        static let width: CGFloat = 350
        static let height: CGFloat = 436
        static let cornerRadius: CGFloat = 36 // Unified corner radius to resolve overlaps
        static let inputBorderWidth: CGFloat = 2 // Centralized input border weight
    }
}
