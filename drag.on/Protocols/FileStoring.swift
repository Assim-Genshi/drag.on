import Foundation

/// Protocol defining the file storage contract, enabling testability and decoupling.
@MainActor
protocol FileStoring: AnyObject {
    var items: [FileItem] { get }
    func addFile(url: URL)
    func addFiles(urls: [URL])
    func removeFile(id: UUID)
    func clearAll()
}
