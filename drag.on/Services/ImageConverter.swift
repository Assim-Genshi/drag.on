import Foundation
import Cocoa
import os
import WebP
import UniformTypeIdentifiers

// MARK: - ConversionEngine

/// Low-level conversion engine with nonisolated methods for each output format.
/// All methods run off the main thread and are safe for concurrent use.
struct ConversionEngine: Sendable {

    private let sipsPath = "/usr/bin/sips"
    private let iconutilPath = "/usr/bin/iconutil"

    // MARK: - Dispatch

    /// Convert a source file to the destination in the specified format.
    func convert(source: URL, destination: URL, format: ImageFormat, quality: Double, isSVGSource: Bool) throws {
        switch format {
        case .webp:
            try convertToWebP(source: source, destination: destination, quality: quality)
        case .png:
            try convertToPNG(source: source, destination: destination)
        case .jpg:
            try convertToJPG(source: source, destination: destination, quality: quality)
        case .icns:
            try convertToICNS(source: source, destination: destination)
        case .ico:
            try convertToICO(source: source, destination: destination)
        case .pdf:
            try convertToPDF(source: source, destination: destination, isSVGSource: isSVGSource)
        }
    }

    // MARK: - WebP (libwebp via Swift-WebP)

    private func convertToWebP(source: URL, destination: URL, quality: Double) throws {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.outputNotCreated(detail: "Failed to load source image for WebP conversion.")
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let stride = width * bytesPerPixel
        let byteCount = stride * height

        var bytes = [UInt8](repeating: 0, count: byteCount)

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ConversionError.outputNotCreated(detail: "Failed to create CGContext for WebP rendering.")
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        let encoder = WebPEncoder()
        let qualityFloat = Float(quality * 100.0)

        let webPData: Data = try bytes.withUnsafeMutableBufferPointer { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                throw ConversionError.outputNotCreated(detail: "Failed to obtain mutable memory address for pixel buffer.")
            }
            return try encoder.encode(
                RGBA: baseAddress,
                config: WebPEncoderConfig.preset(.picture, quality: qualityFloat),
                originWidth: width,
                originHeight: height,
                stride: stride
            )
        }

        try webPData.write(to: destination)
    }

    // MARK: - PNG (CGImageDestination)

    private func convertToPNG(source: URL, destination: URL) throws {
        let cgImage = try loadCGImage(from: source)

        guard let dest = CGImageDestinationCreateWithURL(
            destination as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.outputNotCreated(detail: "Failed to create PNG destination.")
        }

        CGImageDestinationAddImage(dest, cgImage, nil)

        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.outputNotCreated(detail: "Failed to write PNG file.")
        }
    }

    // MARK: - JPG (CGImageDestination with quality)

    private func convertToJPG(source: URL, destination: URL, quality: Double) throws {
        let cgImage = try loadCGImage(from: source)

        guard let dest = CGImageDestinationCreateWithURL(
            destination as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.outputNotCreated(detail: "Failed to create JPEG destination.")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.outputNotCreated(detail: "Failed to write JPEG file.")
        }
    }

    // MARK: - ICNS (sips + iconutil)

    private func convertToICNS(source: URL, destination: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dragon_icns_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let squareSource = tempDir.appendingPathComponent("square_source.png")
        try FileManager.default.copyItem(at: source, to: squareSource)

        let (srcWidth, srcHeight) = try getImageDimensions(url: squareSource)

        if srcWidth != srcHeight {
            let cropSize = min(srcWidth, srcHeight)
            _ = try runProcess(
                executablePath: sipsPath,
                arguments: [
                    "--cropToHeightWidth", "\(cropSize)", "\(cropSize)",
                    squareSource.path
                ]
            )
        }

        _ = try runProcess(
            executablePath: sipsPath,
            arguments: [
                "--resampleHeightWidth", "1024", "1024",
                "-s", "format", "png",
                squareSource.path
            ]
        )

        let iconsetDir = tempDir.appendingPathComponent(
            destination.deletingPathExtension().lastPathComponent + ".iconset"
        )
        try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

        let iconSizes: [(name: String, size: Int)] = [
            ("icon_16x16.png",       16),
            ("icon_16x16@2x.png",    32),
            ("icon_32x32.png",       32),
            ("icon_32x32@2x.png",    64),
            ("icon_128x128.png",     128),
            ("icon_128x128@2x.png",  256),
            ("icon_256x256.png",     256),
            ("icon_256x256@2x.png",  512),
            ("icon_512x512.png",     512),
            ("icon_512x512@2x.png",  1024),
        ]

        for entry in iconSizes {
            let outPath = iconsetDir.appendingPathComponent(entry.name).path
            _ = try runProcess(
                executablePath: sipsPath,
                arguments: [
                    "-s", "format", "png",
                    "--resampleWidth", "\(entry.size)",
                    squareSource.path,
                    "--out", outPath
                ]
            )
        }

        _ = try runProcess(
            executablePath: iconutilPath,
            arguments: ["-c", "icns", iconsetDir.path, "-o", destination.path]
        )

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw ConversionError.outputNotCreated(detail: "iconutil did not produce output.")
        }
    }

    // MARK: - ICO (CGImageDestination multi-size)

    private func convertToICO(source: URL, destination: URL) throws {
        let cgImage = try loadCGImage(from: source)

        // ICO standard sizes
        let icoSizes: [Int] = [16, 24, 32, 48, 64, 128, 256]

        // First, square-crop the source
        let squaredImage = squareCrop(cgImage)

        guard let dest = CGImageDestinationCreateWithURL(
            destination as CFURL,
            "com.microsoft.ico" as CFString,
            icoSizes.count,
            nil
        ) else {
            throw ConversionError.outputNotCreated(detail: "Failed to create ICO destination. The com.microsoft.ico UTI may not be available.")
        }

        for size in icoSizes {
            let resized = try resizeCGImage(squaredImage, to: CGSize(width: size, height: size))
            CGImageDestinationAddImage(dest, resized, nil)
        }

        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.outputNotCreated(detail: "Failed to write ICO file.")
        }
    }

    // MARK: - PDF (CGContext PDF page)

    private func convertToPDF(source: URL, destination: URL, isSVGSource: Bool) throws {
        // For SVG sources, attempt vector-preserving conversion via NSImage → PDF
        if isSVGSource {
            try convertSVGToPDFVector(source: source, destination: destination)
            return
        }

        // For bitmap sources, render as a single PDF page
        let cgImage = try loadCGImage(from: source)
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)

        guard let pdfContext = CGContext(destination as CFURL, mediaBox: &mediaBox, nil) else {
            throw ConversionError.outputNotCreated(detail: "Failed to create PDF context.")
        }

        pdfContext.beginPage(mediaBox: &mediaBox)
        pdfContext.draw(cgImage, in: mediaBox)
        pdfContext.endPage()
        pdfContext.closePDF()
    }

    /// Convert SVG to PDF preserving vector data.
    private func convertSVGToPDFVector(source: URL, destination: URL) throws {
        guard let svgImage = NSImage(contentsOf: source) else {
            throw ConversionError.svgRasterizationFailed(
                detail: "Failed to load SVG for PDF conversion."
            )
        }

        let size = svgImage.size
        guard size.width > 0, size.height > 0 else {
            throw ConversionError.svgRasterizationFailed(
                detail: "SVG has zero dimensions."
            )
        }

        var mediaBox = CGRect(origin: .zero, size: size)

        guard let pdfContext = CGContext(destination as CFURL, mediaBox: &mediaBox, nil) else {
            throw ConversionError.outputNotCreated(detail: "Failed to create PDF context for SVG.")
        }

        pdfContext.beginPage(mediaBox: &mediaBox)

        let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        svgImage.draw(in: NSRect(origin: .zero, size: size))

        NSGraphicsContext.restoreGraphicsState()
        pdfContext.endPage()
        pdfContext.closePDF()
    }

    // MARK: - Image Loading Helpers

    /// Load a CGImage from a file URL.
    private func loadCGImage(from url: URL) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.outputNotCreated(detail: "Failed to load source image from \(url.lastPathComponent).")
        }
        return cgImage
    }

    /// Center-crop a CGImage to a square.
    private func squareCrop(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height

        guard width != height else { return image }

        let size = min(width, height)
        let x = (width - size) / 2
        let y = (height - size) / 2
        let cropRect = CGRect(x: x, y: y, width: size, height: size)

        return image.cropping(to: cropRect) ?? image
    }

    /// Resize a CGImage to the target size with high-quality interpolation.
    private func resizeCGImage(_ image: CGImage, to size: CGSize) throws -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ConversionError.outputNotCreated(detail: "Failed to create resize context.")
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))

        guard let resized = context.makeImage() else {
            throw ConversionError.outputNotCreated(detail: "Failed to create resized image.")
        }

        return resized
    }

    // MARK: - Process Helpers

    private func getImageDimensions(url: URL) throws -> (width: Int, height: Int) {
        let widthOutput = try runProcess(
            executablePath: sipsPath,
            arguments: ["-g", "pixelWidth", url.path]
        )
        let heightOutput = try runProcess(
            executablePath: sipsPath,
            arguments: ["-g", "pixelHeight", url.path]
        )

        guard let width = parsePixelValue(from: widthOutput),
              let height = parsePixelValue(from: heightOutput) else {
            throw ConversionError.dimensionReadFailed
        }
        return (width, height)
    }

    private func parsePixelValue(from output: String) -> Int? {
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("pixel") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2, let val = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    return val
                }
            }
        }
        return nil
    }

    @discardableResult
    private func runProcess(executablePath: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errOutput = String(data: errData, encoding: .utf8) ?? ""
            throw ConversionError.processFailure(
                tool: executablePath,
                code: process.terminationStatus,
                stderr: errOutput
            )
        }

        return output
    }
}

// MARK: - ImageConverter (MainActor Orchestrator)

/// Observable orchestrator that bridges the conversion pipeline to the UI.
///
/// This class manages conversion state for SwiftUI observation and delegates
/// actual conversion work to `ConversionQueue` running off the main thread.
@MainActor
@Observable
final class ImageConverter {

    var state: ConversionState = .idle
    var resolvedOutput: ResolvedOutputInfo?

    /// The active conversion task, if any (for cancellation).
    private var activeTask: Task<Void, Never>?

    /// Path fragments that indicate a temporary/cache source.
    private nonisolated static let tempPathMarkers: [String] = [
        "/var/folders/",
        "/tmp/",
        "/Tmp/",
        "/private/var/folders/",
        "/Caches/",
        "/com.apple.Safari/",
        "/com.google.Chrome/",
        "/org.mozilla.firefox/",
        "/com.microsoft.edgemac/",
    ]

    // MARK: - Public API

    /// Convert a batch of FileItems to the specified format.
    ///
    /// Runs the full pipeline: validate → queue → convert → verify.
    /// Progress is reported via `state` which SwiftUI observes.
    func convertFiles(items: [FileItem], format: ImageFormat, quality: Double, outputDir: URL?) {
        guard !items.isEmpty else { return }

        // Resolve file items to URLs
        let resolvedItems: [(FileItem, URL)] = items.compactMap { item in
            guard let url = item.resolveURL() else { return nil }
            return (item, url)
        }

        guard !resolvedItems.isEmpty else {
            state = .failed(message: "Could not resolve any file paths.", partialResults: [])
            return
        }

        state = .validating

        // Build conversion jobs
        let jobs: [ConversionJob] = resolvedItems.map { (item, sourceURL) in
            let resolved = resolveOutputDirectory(for: sourceURL, customDir: outputDir)
            return ConversionJob(
                sourceURL: sourceURL,
                fileName: item.fileName,
                outputDirectory: resolved.url,
                format: format,
                quality: quality
            )
        }

        // Launch async conversion
        activeTask = Task { [weak self] in
            guard let self = self else { return }

            let queue = ConversionQueue()

            do {
                let results = try await queue.process(jobs: jobs) { [weak self] progress in
                    self?.state = .converting(progress: progress)
                }

                self.state = .success(results: results)
            } catch {
                Logger.converter.error("Conversion batch failed: \(error.localizedDescription)")
                self.state = .failed(message: error.localizedDescription, partialResults: [])
            }
        }
    }

    /// Cancel the active conversion.
    func cancelConversion() {
        activeTask?.cancel()
        activeTask = nil
        state = .idle
    }

    /// Reset converter back to idle state.
    func reset() {
        activeTask?.cancel()
        activeTask = nil
        state = .idle
        resolvedOutput = nil
    }

    // MARK: - Smart Output Resolution

    /// Resolve the best output directory for a source file.
    nonisolated func resolveOutputDirectory(for sourceURL: URL, customDir: URL?) -> ResolvedOutputInfo {
        if let custom = customDir {
            let name = custom.lastPathComponent
            return ResolvedOutputInfo(url: custom, label: name, isWebDrop: false)
        }

        let sourcePath = sourceURL.path
        let isTempSource = Self.tempPathMarkers.contains { sourcePath.contains($0) }

        if isTempSource {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            return ResolvedOutputInfo(url: downloads, label: "Downloads (Web Drop)", isWebDrop: true)
        }

        let parentDir = sourceURL.deletingLastPathComponent()
        let folderName = parentDir.lastPathComponent
        return ResolvedOutputInfo(url: parentDir, label: folderName, isWebDrop: false)
    }

    /// Preview the resolved output info for the first item in a set.
    func previewOutputDirectory(for items: [FileItem], customDir: URL?) {
        guard let first = items.first, let url = first.resolveURL() else {
            resolvedOutput = nil
            return
        }
        resolvedOutput = resolveOutputDirectory(for: url, customDir: customDir)
    }
}
