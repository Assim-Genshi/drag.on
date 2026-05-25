import Cocoa
import SwiftUI

/// Custom hosting view that allows SwiftUI content to respond to clicks
/// even when the window isn't focused. Also forwards file drops to the LairStore.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {

    private weak var lairStore: LairStore?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

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
        if let lairWindow = self.window as? LairWindow {
            lairWindow.isExternalDragActive = true
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        if let lairWindow = self.window as? LairWindow {
            lairWindow.isExternalDragActive = false
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            if let lairWindow = self.window as? LairWindow {
                lairWindow.isExternalDragActive = false
            }
            return false
        }
        if let lairWindow = self.window as? LairWindow {
            lairWindow.cancelShakeAutoClose()
            lairWindow.isExternalDragActive = false
        }
        lairStore?.addFilesAsync(urls: urls)
        return true
    }
}
