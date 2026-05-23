import Cocoa
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct FileItem: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let filePath: String
    let bookmarkData: Data

    /// Create a FileItem from a file URL by generating a security-scoped bookmark.
    static func from(url: URL) -> FileItem? {
        do {
            // Create bookmark for persistent access (no sandbox, so no security scope needed)
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
            print("Failed to create bookmark for \(url.path): \(error)")
            return nil
        }
    }

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
                print("Bookmark is stale for \(fileName)")
                // File still exists at the path, just bookmark is outdated
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
                return nil
            }
            return url
        } catch {
            print("Failed to resolve bookmark for \(fileName): \(error)")
            return nil
        }
    }

    /// Get the file icon from the workspace
    func icon() -> NSImage {
        if let url = resolveURL() {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    /// Get a thumbnail preview of the file (uses QuickLook)
    func thumbnail() -> NSImage {
        guard let url = resolveURL() else { return icon() }

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

        // Wait briefly for thumbnail — fall back to icon if too slow
        let timeout = semaphore.wait(timeout: .now() + 0.5)
        if timeout == .timedOut || result == nil {
            return icon()
        }
        return result!
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}
