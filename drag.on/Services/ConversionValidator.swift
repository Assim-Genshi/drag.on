import Foundation
import os

/// Validates conversion jobs before they enter the queue.
/// All methods are nonisolated and safe to call from any thread.
struct ConversionValidator: Sendable {

    /// The set of file extensions recognized as convertible image inputs.
    private static let supportedInputExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp",
        "heic", "heif", "tiff", "tif", "bmp",
        "svg", "ico", "icns"
    ]

    /// Maximum recommended file size in bytes (50 MB).
    private static let fileSizeLimitBytes: Int64 = 50 * 1024 * 1024

    // MARK: - Public API

    /// Validate a batch of conversion jobs.
    /// Returns one `ValidationResult` per job, in the same order.
    func validate(jobs: [ConversionJob]) -> [ValidationResult] {
        return jobs.map { validate(job: $0) }
    }

    /// Validate a single conversion job.
    func validate(job: ConversionJob) -> ValidationResult {
        let fm = FileManager.default
        let sourcePath = job.sourceURL.path
        let ext = job.sourceURL.pathExtension.lowercased()

        // 1. Check input file exists
        guard fm.fileExists(atPath: sourcePath) else {
            return .invalid(message: "Source file not found: \(job.fileName)")
        }

        // 2. Check input file is readable
        guard fm.isReadableFile(atPath: sourcePath) else {
            return .invalid(message: "Source file is not readable: \(job.fileName)")
        }

        // 3. Check supported input extension
        guard Self.supportedInputExtensions.contains(ext) else {
            return .invalid(message: "Unsupported input format: .\(ext)")
        }

        // 4. Check output directory exists and is writable
        let outputPath = job.outputDirectory.path
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: outputPath, isDirectory: &isDir), isDir.boolValue else {
            return .invalid(message: "Output directory does not exist: \(outputPath)")
        }
        guard fm.isWritableFile(atPath: outputPath) else {
            return .invalid(message: "Output directory is not writable: \(outputPath)")
        }

        // 5. Check format compatibility
        if let incompatibility = checkFormatCompatibility(inputExtension: ext, outputFormat: job.format) {
            return .invalid(message: incompatibility)
        }

        // 6. Check file size (warning only, not blocking)
        if let sizeWarning = checkFileSize(at: job.sourceURL) {
            return .warning(message: sizeWarning)
        }

        return .valid
    }

    // MARK: - Private Helpers

    /// Check if the input→output format pair is compatible.
    /// Returns an error message if incompatible, nil if OK.
    private func checkFormatCompatibility(inputExtension ext: String, outputFormat: ImageFormat) -> String? {
        // SVG can be converted to any format (rasterization pipeline handles it)
        // All bitmap formats can be converted to any output format
        // ICO/ICNS inputs need to be read as images first — CGImageSource handles this
        // No known incompatible pairs after rasterization pipeline is in place
        return nil
    }

    /// Check if the source file exceeds the size limit.
    /// Returns a warning message if over limit, nil if OK.
    private func checkFileSize(at url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? Int64 else {
            return nil
        }

        if fileSize > Self.fileSizeLimitBytes {
            let sizeMB = Int(fileSize / (1024 * 1024))
            let limitMB = Int(Self.fileSizeLimitBytes / (1024 * 1024))
            return "\(url.lastPathComponent) is \(sizeMB) MB (recommended limit: \(limitMB) MB). Conversion may be slow."
        }

        return nil
    }
}
