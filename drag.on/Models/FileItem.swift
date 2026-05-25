import Cocoa
import QuickLookThumbnailing
import UniformTypeIdentifiers
import os
import ImageIO

/// Represents a file stored in the Lair with persistent bookmark access.
struct FileItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let fileName: String
    let filePath: String
    let bookmarkData: Data

    // MARK: - Factory

    /// Create a FileItem from a file URL by generating a bookmark.
    static func from(url: URL) -> FileItem? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return FileItem(
                id: UUID(),
                fileName: url.lastPathComponent,
                filePath: url.path,
                bookmarkData: bookmarkData
            )
        } catch {
            Logger.fileItem.error("Failed to create bookmark for \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - URL Resolution

    /// Resolve the bookmark back to a URL. Returns nil if stale or invalid.
    func resolveURL() -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                Logger.fileItem.warning("Bookmark is stale for \(fileName)")
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
                return nil
            }
            return url
        } catch {
            Logger.fileItem.error("Failed to resolve bookmark for \(fileName): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Icons & Thumbnails

    /// Get the file icon from the workspace (fast, no I/O).
    @MainActor
    func icon() -> NSImage {
        if let url = resolveURL(), FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let pathExtension = (fileName as NSString).pathExtension
        if let type = UTType(filenameExtension: pathExtension) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    /// Lightweight placeholder for immediate display while async thumbnail loads.
    /// Uses the system icon which is always fast and cached by the OS.
    @MainActor
    func placeholderImage() -> NSImage {
        if let url = resolveURL(), FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        let pathExtension = (fileName as NSString).pathExtension
        if let type = UTType(filenameExtension: pathExtension) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    /// Synchronous thumbnail for drag preview images (backward compat).
    /// Prefer `thumbnailAsync()` for display in views.
    @MainActor
    func thumbnail() -> NSImage {
        if let cached = ThumbnailCache.shared.cachedImage(for: filePath) {
            return cached
        }

        guard let url = resolveURL() else {
            return placeholderImage()
        }

        if isImage {
            // For SVGs, load natively via NSImage to preserve vectors and transparency
            if url.pathExtension.lowercased() == "svg" {
                if let img = NSImage(contentsOf: url) {
                    return img
                }
            }

            // For other images, use CGImageSource for memory-efficient downsampled thumbnails
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            if let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) {
                let thumbnailOptions: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: 180
                ]
                if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) {
                    let cgSize = NSSize(width: cgImage.width, height: cgImage.height)
                    return NSImage(cgImage: cgImage, size: cgSize)
                }
            }
        }

        return placeholderImage()
    }

    /// Async thumbnail generation routed through `ThumbnailCache`.
    /// Uses QLThumbnailGenerator for hardware-accelerated, Retina-quality previews.
    @MainActor
    func thumbnailAsync(size: CGSize = CGSize(width: 180, height: 180)) async -> NSImage {
        guard let url = resolveURL() else {
            return placeholderImage()
        }

        return await ThumbnailCache.shared.thumbnail(
            for: filePath,
            url: url,
            size: size,
            isImage: isImage
        )
    }

    // MARK: - Image Detection

    /// Whether this file is a recognized image format.
    var isImage: Bool {
        SupportedImageExtensions.isImage(fileName: fileName)
    }

    // MARK: - Equatable

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}
