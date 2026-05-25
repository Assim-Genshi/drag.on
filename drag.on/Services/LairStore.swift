import Foundation
import os

/// Observable store managing the list of files in the Lair.
/// Handles persistence via UserDefaults and prunes stale bookmarks on launch.
@MainActor
@Observable
final class LairStore: FileStoring {

    // MARK: - Published State

    var items: [FileItem] = []
    var previousItems: [FileItem] = []

    // MARK: - Private

    private let storageKey = "dragOnLairItems"
    private let previousStorageKey = "dragOnPreviousLairItems"

    // MARK: - Initialization

    init() {
        loadItems()
        loadPreviousItems()
    }

    // MARK: - Public API

    /// Add a file to the lair from a URL.
    func addFile(url: URL) {
        guard !items.contains(where: { $0.filePath == url.path }) else { return }

        if let item = FileItem.from(url: url) {
            items.append(item)
            saveItems()
        }
    }

    /// Add multiple files at once (batched save).
    func addFiles(urls: [URL]) {
        var didAdd = false
        for url in urls {
            guard !items.contains(where: { $0.filePath == url.path }) else { continue }
            if let item = FileItem.from(url: url) {
                items.append(item)
                didAdd = true
            }
        }
        if didAdd {
            saveItems()
        }
    }

    /// Add multiple files asynchronously — offloads bookmark creation to background threads.
    /// Results are batched and published atomically on the MainActor.
    func addFilesAsync(urls: [URL]) {
        let existingPaths = Set(items.map(\.filePath))
        let newURLs = urls.filter { !existingPaths.contains($0.path) }
        guard !newURLs.isEmpty else { return }

        Task(priority: .userInitiated) {
            let newItems = await withTaskGroup(of: FileItem?.self, returning: [FileItem].self) { group in
                for url in newURLs {
                    group.addTask {
                        // Bookmark creation runs off the main thread
                        FileItem.from(url: url)
                    }
                }
                var results: [FileItem] = []
                for await item in group {
                    if let item { results.append(item) }
                }
                return results
            }

            guard !newItems.isEmpty else { return }

            // Publish atomically on the MainActor
            await MainActor.run {
                self.items.append(contentsOf: newItems)
                self.saveItems()
            }
        }
    }

    /// Remove a file from the lair by ID.
    func removeFile(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }

    /// Replace a file item's URL in the store (e.g. after rename).
    func replaceFile(id: UUID, with newURL: URL) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let newItem = FileItem.from(url: newURL) {
            items[index] = newItem
            saveItems()
        }
    }

    /// Clear all items from the lair.
    func clearAll() {
        items.removeAll()
        saveItems()
        ThumbnailCache.shared.clear()
    }

    /// Whether all items in the lair are images.
    var allItemsAreImages: Bool {
        !items.isEmpty && items.allSatisfy { $0.isImage }
    }

    /// Whether at least one item in the lair is an image.
    var hasImages: Bool {
        items.contains { $0.isImage }
    }

    // MARK: - Persistence

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
            
            if !items.isEmpty {
                previousItems = items
                savePreviousItems()
            }
        } catch {
            Logger.lairStore.error("Failed to save lair items: \(error.localizedDescription)")
        }
    }

    private func savePreviousItems() {
        do {
            let data = try JSONEncoder().encode(previousItems)
            UserDefaults.standard.set(data, forKey: previousStorageKey)
        } catch {
            Logger.lairStore.error("Failed to save previous lair items: \(error.localizedDescription)")
        }
    }

    private func loadPreviousItems() {
        guard let data = UserDefaults.standard.data(forKey: previousStorageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([FileItem].self, from: data)
            previousItems = decoded.filter { item in
                let url = item.resolveURL()
                return url != nil
            }
            if previousItems.count != decoded.count {
                savePreviousItems()
            }
        } catch {
            Logger.lairStore.error("Failed to load previous lair items: \(error.localizedDescription)")
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        do {
            let decoded = try JSONDecoder().decode([FileItem].self, from: data)
            items = decoded.filter { item in
                let url = item.resolveURL()
                if url == nil {
                    Logger.lairStore.info("Pruning stale item: \(item.fileName)")
                }
                return url != nil
            }
            if items.count != decoded.count {
                saveItems()
            }
        } catch {
            Logger.lairStore.error("Failed to load lair items: \(error.localizedDescription)")
        }
    }

    /// Restore the previous non-empty lair items into the active list.
    func restorePreviousLair() {
        if !previousItems.isEmpty {
            items = previousItems
            saveItems()
        }
    }
}
