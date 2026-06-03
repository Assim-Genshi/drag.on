import Cocoa
import Quartz

/// Coordinator that serves as both data source and delegate for QLPreviewPanel,
/// allowing Quick Look to preview multiple files from the Lair.
/// Not isolated to @MainActor because QLPreviewPanelDataSource/Delegate
/// protocol requirements are nonisolated. The urls array is immutable and safe.
final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    private let urls: [URL]

    init(urls: [URL]) {
        self.urls = urls
        super.init()
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}
