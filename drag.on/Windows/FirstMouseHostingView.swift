import Cocoa
import SwiftUI

/// Custom hosting view that allows SwiftUI content to respond to clicks
/// even when the window isn't focused. Also forwards file drops to the LairStore.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {

    private weak var lairStore: LairStore?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Register this view as a drop target that forwards to the store.
    func enableDropForwarding(store: LairStore) {
        self.lairStore = store
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) else { return [] }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else { return false }
        lairStore?.addFiles(urls: urls)
        return true
    }
}
