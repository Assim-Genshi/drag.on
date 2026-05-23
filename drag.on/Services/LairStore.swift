import Foundation
import os

/// Observable store managing the list of files in the Lair.
/// Handles persistence via UserDefaults and prunes stale bookmarks on launch.
@MainActor
@Observable
final class LairStore: FileStoring {

    // MARK: - Published State

    var items: [FileItem] = []

    // MARK: - Private

    private let storageKey = "dragOnLairItems"

    // MARK: - Initialization

    init() {
        loadItems()
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

    /// Remove a file from the lair by ID.
    func removeFile(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }

    /// Clear all items from the lair.
    func clearAll() {
        items.removeAll()
        saveItems()
    }

    /// Whether all items in the lair are images.
    var allItemsAreImages: Bool {
        !items.isEmpty && items.allSatisfy { $0.isImage }
    }

    // MARK: - Persistence

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Logger.lairStore.error("Failed to save lair items: \(error.localizedDescription)")
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
}
