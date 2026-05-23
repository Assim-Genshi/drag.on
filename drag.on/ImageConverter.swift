import Foundation
import Cocoa
import Combine

// MARK: - Conversion Types

enum ImageFormat: String, CaseIterable, Identifiable {
    case webp = "WebP"
    case icns = "ICNS"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .webp: return "webp"
        case .icns: return "icns"
        }
    }
}

enum ConversionState: Equatable {
    case idle
    case converting(current: String, index: Int, total: Int)
    case success(outputURLs: [URL])
    case failed(message: String)
}

/// Describes the resolved output location and a human-readable label for the UI.
struct ResolvedOutputInfo: Equatable {
    let url: URL
    let label: String       // e.g. "Same Folder", "Downloads (Web Drop)", "Desktop"
    let isWebDrop: Bool
}

// MARK: - ImageConverter

/// Handles image format conversion using native macOS CLI tools (sips, iconutil).
/// All work runs on background threads. UI state is published for SwiftUI binding.
/// Concurrency is bounded to 3 parallel conversions via a semaphore.
class ImageConverter: ObservableObject {

    @Published var state: ConversionState = .idle
    @Published var resolvedOutput: ResolvedOutputInfo?

    private let sipsPath = "/usr/bin/sips"
    private let iconutilPath = "/usr/bin/iconutil"
    private let maxConcurrent = 3

    /// Path fragments that indicate a temporary/cache source (browser downloads, etc.)
    private static let tempPathMarkers: [String] = [
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
    /// - Parameters:
    ///   - items: Array of FileItems to convert (must be images).
    ///   - format: Target format (WebP or ICNS).
    ///   - outputDir: Optional custom output directory. Nil = same folder as source.
    func convertFiles(items: [FileItem], format: ImageFormat, outputDir: URL?) {
        guard !items.isEmpty else { return }

        let resolvedItems: [(FileItem, URL)] = items.compactMap { item in
            guard let url = item.resolveURL() else { return nil }
            return (item, url)
        }

        guard !resolvedItems.isEmpty else {
            DispatchQueue.main.async {
                self.state = .failed(message: "Could not resolve any file paths.")
            }
            return
        }

        DispatchQueue.main.async {
            self.state = .converting(current: resolvedItems[0].0.fileName, index: 0, total: resolvedItems.count)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let semaphore = DispatchSemaphore(value: self.maxConcurrent)
            let group = DispatchGroup()
            let lock = NSLock()
            var outputURLs: [URL] = []
            var errors: [String] = []

            for (index, (item, sourceURL)) in resolvedItems.enumerated() {
                semaphore.wait()
                group.enter()

                DispatchQueue.main.async {
                    self.state = .converting(current: item.fileName, index: index, total: resolvedItems.count)
                }

                DispatchQueue.global(qos: .userInitiated).async {
                    defer {
                        semaphore.signal()
                        group.leave()
                    }

                    let resolved = self.resolveOutputDirectory(for: sourceURL, customDir: outputDir)
                    let baseName = sourceURL.deletingPathExtension().lastPathComponent
                    let destURL = resolved.url.appendingPathComponent("\(baseName).\(format.fileExtension)")

                    do {
                        switch format {
                        case .webp:
                            try self.convertToWebP(source: sourceURL, destination: destURL)
                        case .icns:
                            try self.convertToICNS(source: sourceURL, destination: destURL)
                        }

                        lock.lock()
                        outputURLs.append(destURL)
                        lock.unlock()
                    } catch {
                        lock.lock()
                        errors.append("\(item.fileName): \(error.localizedDescription)")
                        lock.unlock()
                    }
                }
            }

            group.wait()

            DispatchQueue.main.async {
                if !outputURLs.isEmpty {
                    self.state = .success(outputURLs: outputURLs)
                } else {
                    self.state = .failed(message: errors.joined(separator: "\n"))
                }
            }
        }
    }

    /// Reset converter back to idle state.
    func reset() {
        state = .idle
        resolvedOutput = nil
    }

    // MARK: - Smart Output Resolution

    /// Resolve the best output directory for a source file.
    /// If the user picked a custom directory, always use that.
    /// If "Same Folder" is selected but the source lives in a temp/cache path
    /// (e.g. browser drag), fall back to ~/Downloads.
    func resolveOutputDirectory(for sourceURL: URL, customDir: URL?) -> ResolvedOutputInfo {
        // User explicitly chose a folder — honour it
        if let custom = customDir {
            let name = custom.lastPathComponent
            return ResolvedOutputInfo(url: custom, label: name, isWebDrop: false)
        }

        let sourcePath = sourceURL.path
        let isTempSource = Self.tempPathMarkers.contains { sourcePath.contains($0) }

        if isTempSource {
            // Redirect to ~/Downloads as a safe, user-visible location
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            return ResolvedOutputInfo(url: downloads, label: "Downloads (Web Drop)", isWebDrop: true)
        }

        // Normal local file — output next to the source
        let parentDir = sourceURL.deletingLastPathComponent()
        let folderName = parentDir.lastPathComponent
        return ResolvedOutputInfo(url: parentDir, label: folderName, isWebDrop: false)
    }

    /// Preview the resolved output info for the first item in a set
    /// so the UI can show the destination label before the user clicks Convert.
    func previewOutputDirectory(for items: [FileItem], customDir: URL?) {
        guard let first = items.first, let url = first.resolveURL() else {
            resolvedOutput = nil
            return
        }
        resolvedOutput = resolveOutputDirectory(for: url, customDir: customDir)
    }

    // MARK: - WebP Conversion

    /// Convert a single image to WebP using sips.
    private func convertToWebP(source: URL, destination: URL) throws {
        // sips -s format webp <source> --out <destination>
        let result = try runProcess(
            executablePath: sipsPath,
            arguments: ["-s", "format", "webp", source.path, "--out", destination.path]
        )

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw ConversionError.outputNotCreated(detail: result)
        }
    }

    // MARK: - ICNS Conversion

    /// Convert a single image to ICNS with center-crop and multi-scale iconset generation.
    private func convertToICNS(source: URL, destination: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dragon_icns_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Step 1: Create a center-cropped square copy
        let squareSource = tempDir.appendingPathComponent("square_source.png")
        try FileManager.default.copyItem(at: source, to: squareSource)

        let (srcWidth, srcHeight) = try getImageDimensions(url: squareSource)

        if srcWidth != srcHeight {
            // Center-crop to the smaller dimension
            let cropSize = min(srcWidth, srcHeight)
            _ = try runProcess(
                executablePath: sipsPath,
                arguments: [
                    "--cropToHeightWidth", "\(cropSize)", "\(cropSize)",
                    squareSource.path
                ]
            )
        }

        // Step 2: Resize the squared image to 1024x1024
        _ = try runProcess(
            executablePath: sipsPath,
            arguments: [
                "--resampleHeightWidth", "1024", "1024",
                "-s", "format", "png",
                squareSource.path
            ]
        )

        // Step 3: Generate iconset
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

        // Step 4: Run iconutil to compile the .icns
        _ = try runProcess(
            executablePath: iconutilPath,
            arguments: ["-c", "icns", iconsetDir.path, "-o", destination.path]
        )

        guard FileManager.default.fileExists(atPath: destination.path) else {
            throw ConversionError.outputNotCreated(detail: "iconutil did not produce output.")
        }
    }

    // MARK: - Helpers

    /// Get the pixel dimensions of an image using sips.
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

    /// Parse a pixel value from sips output like "  pixelWidth: 1024"
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

    /// Run a subprocess synchronously, returning stdout. Throws on non-zero exit.
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
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
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

// MARK: - Errors

enum ConversionError: LocalizedError {
    case outputNotCreated(detail: String)
    case dimensionReadFailed
    case processFailure(tool: String, code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .outputNotCreated(let detail):
            return "Output file was not created. \(detail)"
        case .dimensionReadFailed:
            return "Could not read image dimensions."
        case .processFailure(let tool, let code, let stderr):
            return "\(tool) exited with code \(code): \(stderr)"
        }
    }
}
