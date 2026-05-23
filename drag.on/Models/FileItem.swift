import Cocoa
import QuickLookThumbnailing
import UniformTypeIdentifiers
import os

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

    /// Get the file icon from the workspace.
    @MainActor
    func icon() -> NSImage {
        if let url = resolveURL() {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    /// Get a thumbnail preview of the file (synchronous, uses QuickLook).
    /// Falls back to the system icon if thumbnail generation is too slow.
    @MainActor
    func thumbnail() -> NSImage {
        guard let url = resolveURL() else {
            return NSWorkspace.shared.icon(for: .data)
        }

        let size = CGSize(width: 180, height: 180)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 2.0,
            representationTypes: .thumbnail
        )

        var result: NSImage?
        let semaphore = DispatchSemaphore(value: 0)

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            if let rep = rep {
                result = rep.nsImage
            }
            semaphore.signal()
        }

        let timeout = semaphore.wait(timeout: .now() + 0.5)
        if timeout == .timedOut || result == nil {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return result!
    }

    /// Async variant of thumbnail generation for modern Swift concurrency contexts.
    @MainActor
    func thumbnailAsync(size: CGSize = CGSize(width: 180, height: 180)) async -> NSImage {
        guard let url = resolveURL() else {
            return NSWorkspace.shared.icon(for: .data)
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 2.0,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
                DispatchQueue.main.async {
                    if let rep = rep {
                        continuation.resume(returning: rep.nsImage)
                    } else {
                        continuation.resume(returning: NSWorkspace.shared.icon(forFile: url.path))
                    }
                }
            }
        }
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
