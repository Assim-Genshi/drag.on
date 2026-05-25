import Cocoa

/// Root view that accepts file drops and forwards them to the LairStore.
final class DropTargetView: NSView {

    private let store: LairStore

    init(store: LairStore) {
        self.store = store
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) else {
            return []
        }
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
        store.addFilesAsync(urls: urls)
        return true
    }
}
