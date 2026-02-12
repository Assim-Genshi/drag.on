import Foundation
import Combine

class ShelfStore: ObservableObject {
    @Published var items: [FileItem] = []

    private let storageKey = "dragOnShelfItems"

    init() {
        loadItems()
    }

    // MARK: - Public API

    /// Add a file to the shelf from a URL
    func addFile(url: URL) {
        // Don't add duplicates (same path)
        guard !items.contains(where: { $0.filePath == url.path }) else { return }

        if let item = FileItem.from(url: url) {
            items.append(item)
            saveItems()
        }
    }

    /// Add multiple files at once
    func addFiles(urls: [URL]) {
        for url in urls {
            addFile(url: url)
        }
    }

    /// Remove a file from the shelf by ID
    func removeFile(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }

    /// Clear all items from the shelf
    func clearAll() {
        items.removeAll()
        saveItems()
    }

    // MARK: - Persistence

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save shelf items: \(error)")
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        do {
            let decoded = try JSONDecoder().decode([FileItem].self, from: data)
            // Validate bookmarks and prune stale ones
            items = decoded.filter { item in
                let url = item.resolveURL()
                if url == nil {
                    print("Pruning stale item: \(item.fileName)")
                }
                return url != nil
            }
            // Re-save if we pruned any
            if items.count != decoded.count {
                saveItems()
            }
        } catch {
            print("Failed to load shelf items: \(error)")
        }
    }
}
