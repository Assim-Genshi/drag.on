import Cocoa
import QuickLookThumbnailing
import ImageIO
import os

/// A `Sendable` wrapper for `NSImage` that allows crossing actor boundaries.
/// `NSImage` is safe to create on a background thread and read on the main thread,
/// but Apple's framework headers do not mark it as `Sendable`.
struct SendableImage: @unchecked Sendable {
    let image: NSImage
}

/// Main-actor-isolated thumbnail cache that generates thumbnails off the main thread.
/// Uses `NSCache` for automatic memory management and coalescing duplicate requests.
@MainActor
final class ThumbnailCache {

    static let shared = ThumbnailCache()

    // MARK: - Storage

    private let cache = NSCache<NSUUID, NSImage>()
    private var inProgress: [UUID: Task<SendableImage, Never>] = [:]

    private init() {
        cache.countLimit = 100
    }

    // MARK: - Lookup

    /// Return a cached thumbnail if available.
    func cachedImage(for id: UUID) -> NSImage? {
        cache.object(forKey: id as NSUUID)
    }

    /// Store a thumbnail in the cache.
    func store(_ image: NSImage, for id: UUID) {
        cache.setObject(image, forKey: id as NSUUID)
    }

    /// Remove a single entry.
    func remove(for id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
        inProgress[id]?.cancel()
        inProgress.removeValue(forKey: id)
    }

    /// Clear the entire cache.
    func clear() {
        cache.removeAllObjects()
        for task in inProgress.values { task.cancel() }
        inProgress.removeAll()
    }

    // MARK: - Generation

    /// Generate a thumbnail for a file item, coalescing duplicate requests.
    /// Returns a cached result immediately if available, otherwise generates
    /// via QLThumbnailGenerator on a background thread and caches the result.
    func thumbnail(
        for id: UUID,
        url: URL,
        size: CGSize = CGSize(width: 180, height: 180),
        isImage: Bool
    ) async -> NSImage {
        // 1. Return cached
        if let cached = cache.object(forKey: id as NSUUID) {
            return cached
        }

        // 2. Join in-progress request
        if let existing = inProgress[id] {
            let wrapped = await existing.value
            return wrapped.image
        }

        // 3. Start new generation on a background thread
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let task = Task<SendableImage, Never>.detached(priority: .userInitiated) {
            await Self.generateThumbnail(url: url, size: size, scale: scale, isImage: isImage)
        }
        inProgress[id] = task

        let wrapped = await task.value
        let result = wrapped.image
        cache.setObject(result, forKey: id as NSUUID)
        inProgress.removeValue(forKey: id)
        return result
    }

    // MARK: - Private Generation (runs off main thread via Task.detached)

    /// Generate a thumbnail using QLThumbnailGenerator, falling back to
    /// CGImageSource downsampling for images and NSWorkspace icon for others.
    nonisolated private static func generateThumbnail(
        url: URL,
        size: CGSize,
        scale: CGFloat,
        isImage: Bool
    ) async -> SendableImage {
        // Try QLThumbnailGenerator first (hardware-accelerated)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            return SendableImage(image: representation.nsImage)
        } catch {
            Logger.thumbnailCache.debug("QL thumbnail failed for \(url.lastPathComponent): \(error.localizedDescription)")
        }

        // Fallback: CGImageSource for images
        if isImage {
            if let image = downsampleImage(at: url, maxPixelSize: max(size.width, size.height) * scale) {
                return SendableImage(image: image)
            }
        }

        // Final fallback: system icon (must access on main actor)
        return await MainActor.run {
            SendableImage(image: NSWorkspace.shared.icon(forFile: url.path))
        }
    }

    /// Memory-efficient CGImageSource downsampling.
    nonisolated private static func downsampleImage(at url: URL, maxPixelSize: CGFloat) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary
        ) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
}
