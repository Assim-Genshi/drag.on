import Cocoa
import QuickLookThumbnailing
import ImageIO
import os
import UniformTypeIdentifiers

/// A `Sendable` wrapper for `NSImage` that allows crossing actor boundaries.
/// `NSImage` is safe to create on a background thread and read on the main thread,
/// but Apple's framework headers do not mark it as `Sendable`.
struct SendableImage: @unchecked Sendable {
    let image: NSImage
}

/// A cached thumbnail representation containing metadata for validation.
final class CachedThumbnail: NSObject, @unchecked Sendable {
    let image: NSImage
    let modificationDate: Date
    let size: CGSize
    let scale: CGFloat

    init(image: NSImage, modificationDate: Date, size: CGSize, scale: CGFloat) {
        self.image = image
        self.modificationDate = modificationDate
        self.size = size
        self.scale = scale
    }
}

/// Main-actor-isolated thumbnail cache that generates thumbnails off the main thread.
/// Uses `NSCache` for automatic memory management and coalescing duplicate requests.
@MainActor
final class ThumbnailCache {

    static let shared = ThumbnailCache()

    // MARK: - Storage

    private let cache = NSCache<NSString, CachedThumbnail>()
    private var inProgress: [String: Task<SendableImage, Never>] = [:]

    private init() {
        cache.countLimit = 100
    }

    // MARK: - Lookup

    /// Return a cached thumbnail if available.
    func cachedImage(for filePath: String) -> NSImage? {
        cache.object(forKey: filePath as NSString)?.image
    }

    /// Store a thumbnail in the cache.
    func store(_ image: NSImage, for filePath: String, modificationDate: Date, size: CGSize, scale: CGFloat) {
        let cached = CachedThumbnail(image: image, modificationDate: modificationDate, size: size, scale: scale)
        cache.setObject(cached, forKey: filePath as NSString)
    }

    /// Remove a single entry.
    func remove(for filePath: String) {
        cache.removeObject(forKey: filePath as NSString)
        inProgress[filePath]?.cancel()
        inProgress.removeValue(forKey: filePath)
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
        for filePath: String,
        url: URL,
        size: CGSize = CGSize(width: 180, height: 180),
        isImage: Bool
    ) async -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        // 1. Get modification date of the file on a background thread (avoid disk I/O on main actor)
        let modDate = await Task.detached(priority: .userInitiated) {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date(timeIntervalSince1970: 0)
        }.value

        // 2. Check the cache on the MainActor
        if let cached = cache.object(forKey: filePath as NSString) {
            if cached.modificationDate == modDate && cached.size == size && cached.scale == scale {
                return cached.image
            }
        }

        // 3. Join in-progress request if one is running
        if let existing = inProgress[filePath] {
            let wrapped = await existing.value
            return wrapped.image
        }

        // 4. Start new generation on a background thread
        let task = Task<SendableImage, Never>.detached(priority: .userInitiated) {
            await Self.generateThumbnail(url: url, size: size, scale: scale, isImage: isImage)
        }
        inProgress[filePath] = task

        let wrapped = await task.value
        let result = wrapped.image
        
        // 5. Store in cache on MainActor
        let cached = CachedThumbnail(image: result, modificationDate: modDate, size: size, scale: scale)
        cache.setObject(cached, forKey: filePath as NSString)
        inProgress.removeValue(forKey: filePath)
        
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

        // Fallback 1: CGImageSource for images
        if isImage {
            if let image = downsampleImage(at: url, maxPixelSize: max(size.width, size.height) * scale) {
                return SendableImage(image: image)
            }
        }

        // Fallback 2: file icon & Fallback 3: generic icon (must run on main actor)
        return await MainActor.run {
            // First check if the file exists at url.path
            if FileManager.default.fileExists(atPath: url.path) {
                return SendableImage(image: NSWorkspace.shared.icon(forFile: url.path))
            }
            
            // If it doesn't exist, try getting the UTType icon based on extension
            if let type = UTType(filenameExtension: url.pathExtension) {
                return SendableImage(image: NSWorkspace.shared.icon(for: type))
            }
            
            // If everything fails, fall back to a completely generic icon
            return SendableImage(image: NSWorkspace.shared.icon(for: .data))
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
