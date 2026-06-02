//
//  AsyncThumbnailView.swift
//  drag.on
//
//  Created by assim on 2026-5-30.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Async Thumbnail View

struct AsyncThumbnailView: View {
    let url: URL
    let size: CGSize

    @State private var image: NSImage?

    init(url: URL, size: CGSize) {
        self.url = url
        self.size = size
        let cached = ThumbnailCache.shared.cachedImage(for: url.path)
        self._image = State(initialValue: cached)
    }

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
            } else {
                Image(nsImage: placeholderIcon)
                    .resizable()
            }
        }
        .task(id: url) {
            let isImage = SupportedImageExtensions.isImage(fileName: url.lastPathComponent)
            
            // Check cache to avoid reloading if already cached
            if let cached = ThumbnailCache.shared.cachedImage(for: url.path) {
                self.image = cached
            } else {
                self.image = await ThumbnailCache.shared.thumbnail(
                    for: url.path,
                    url: url,
                    size: size,
                    isImage: isImage
                )
            }
        }
    }

    private var placeholderIcon: NSImage {
        if FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let type = UTType(filenameExtension: url.pathExtension) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }
}
