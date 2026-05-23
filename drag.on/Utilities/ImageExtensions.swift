import Foundation

/// Centralized set of recognized image file extensions.
/// Used by LairView (convert button visibility) and FileCountLabel (display text).
enum SupportedImageExtensions {
    static let all: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp",
        "heic", "heif", "tiff", "tif", "bmp",
        "svg", "ico", "icns"
    ]

    /// Check if a filename has an image extension.
    static func isImage(fileName: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return all.contains(ext)
    }
}
