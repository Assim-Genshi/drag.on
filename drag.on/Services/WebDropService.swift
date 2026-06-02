import Foundation
import Cocoa
import os

/// Handles downloading web resources dropped into the Lair.
actor WebDropService {
    static let shared = WebDropService()
    
    private init() {}
    
    /// The directory where web drops should be saved.
    private var downloadDirectory: URL {
        let savedPath = UserDefaults.standard.string(forKey: "webDropLocationPath") ?? ""
        if !savedPath.isEmpty {
            let url = URL(fileURLWithPath: savedPath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        // Fallback to Downloads folder
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
    
    /// Downloads an image from the given URL and saves it locally.
    /// - Parameter remoteURL: The web URL of the image.
    /// - Returns: The local file URL where the image was saved.
    func downloadImage(from remoteURL: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Try to derive a meaningful filename
        var filename = remoteURL.lastPathComponent
        if filename.isEmpty || filename == "/" {
            filename = UUID().uuidString
        }
        
        // Ensure proper extension if missing, using mime type
        if let mimeType = httpResponse.mimeType, let ext = fileExtension(for: mimeType) {
            let currentExt = (filename as NSString).pathExtension
            if currentExt.isEmpty || currentExt.lowercased() != ext {
                filename = (filename as NSString).deletingPathExtension + "." + ext
            }
        } else if (filename as NSString).pathExtension.isEmpty {
            filename += ".jpg" // Fallback
        }
        
        // Generate a unique destination URL to avoid overwriting
        let destinationDir = downloadDirectory
        var destinationURL = destinationDir.appendingPathComponent(filename)
        var counter = 1
        
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let name = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            destinationURL = destinationDir.appendingPathComponent("\(name) \(counter).\(ext)")
            counter += 1
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
    
    private func fileExtension(for mimeType: String) -> String? {
        switch mimeType.lowercased() {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "image/heic": return "heic"
        case "image/svg+xml": return "svg"
        default: return nil
        }
    }
}
