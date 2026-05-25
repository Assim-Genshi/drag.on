import Foundation

// MARK: - Conversion Job

/// Represents a single file conversion request to be processed by the queue.
struct ConversionJob: Identifiable, Sendable {
    let id: UUID
    let sourceURL: URL
    let fileName: String
    let outputDirectory: URL
    let format: ImageFormat
    let quality: Double
    let overwritePolicy: OverwritePolicy

    init(
        sourceURL: URL,
        fileName: String,
        outputDirectory: URL,
        format: ImageFormat,
        quality: Double,
        overwritePolicy: OverwritePolicy = .autoRename
    ) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.fileName = fileName
        self.outputDirectory = outputDirectory
        self.format = format
        self.quality = quality
        self.overwritePolicy = overwritePolicy
    }
}

// MARK: - Conversion Result

/// The outcome of a single file conversion.
struct ConversionResult: Equatable, Sendable {
    let originalURL: URL
    let convertedURL: URL
    let format: ImageFormat
    let fileSize: Int64
    let duration: TimeInterval
}

// MARK: - Conversion Progress

/// Granular progress report for a conversion batch.
struct ConversionProgress: Equatable, Sendable {
    let currentFileName: String
    let currentIndex: Int
    let totalCount: Int
    let phase: ConversionPhase

    /// Fractional completion from 0.0 to 1.0.
    var fractionComplete: Double {
        guard totalCount > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCount)
    }
}

/// The current phase of processing for a single file.
enum ConversionPhase: String, Equatable, Sendable {
    case validating   = "Validating"
    case rasterizing  = "Rasterizing SVG"
    case converting   = "Converting"
    case verifying    = "Verifying"
}

// MARK: - Conversion State

/// Describes the overall state of a conversion batch.
enum ConversionState: Equatable, Sendable {
    case idle
    case validating
    case converting(progress: ConversionProgress)
    case success(results: [ConversionResult])
    case failed(message: String, partialResults: [ConversionResult])

    // Equatable conformance for associated values
    static func == (lhs: ConversionState, rhs: ConversionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.validating, .validating):
            return true
        case (.converting(let a), .converting(let b)):
            return a == b
        case (.success(let a), .success(let b)):
            return a == b
        case (.failed(let msgA, let resultsA), .failed(let msgB, let resultsB)):
            return msgA == msgB && resultsA == resultsB
        default:
            return false
        }
    }
}

// MARK: - Resolved Output Info

/// Describes the resolved output location and a human-readable label for the UI.
struct ResolvedOutputInfo: Equatable, Sendable {
    let url: URL
    let label: String
    let isWebDrop: Bool
}

// MARK: - Overwrite Policy

/// Controls behavior when a destination file already exists.
enum OverwritePolicy: String, Sendable {
    /// Generate a unique name: `file (1).webp`, `file (2).webp`, etc.
    case autoRename
    /// Silently replace the existing file.
    case overwrite
    /// Skip the file and report it.
    case skip
}

// MARK: - Conversion Errors

/// Rich error type with actionable messages for every failure mode.
enum ConversionError: LocalizedError, Equatable {
    case unsupportedInput(extension: String)
    case unsupportedConversion(from: String, to: ImageFormat)
    case inputFileNotFound(path: String)
    case inputNotReadable(path: String)
    case outputDirectoryNotWritable(path: String)
    case svgRasterizationFailed(detail: String)
    case outputNotCreated(detail: String)
    case outputVerificationFailed(path: String, detail: String)
    case processFailure(tool: String, code: Int32, stderr: String)
    case overwriteBlocked(path: String)
    case fileTooLarge(sizeMB: Int, limitMB: Int)
    case dimensionReadFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedInput(let ext):
            return "The file type '.\(ext)' is not supported for conversion."
        case .unsupportedConversion(let from, let to):
            return "Cannot convert .\(from) to \(to.rawValue)."
        case .inputFileNotFound(let path):
            return "Source file not found at '\(path)'."
        case .inputNotReadable(let path):
            return "Source file at '\(path)' is not readable."
        case .outputDirectoryNotWritable(let path):
            return "Output directory '\(path)' is not writable."
        case .svgRasterizationFailed(let detail):
            return "Failed to rasterize SVG: \(detail)"
        case .outputNotCreated(let detail):
            return "Output file was not created. \(detail)"
        case .outputVerificationFailed(let path, let detail):
            return "Converted file at '\(path)' is invalid: \(detail)"
        case .processFailure(let tool, let code, let stderr):
            let toolName = (tool as NSString).lastPathComponent
            return "\(toolName) exited with code \(code): \(stderr)"
        case .overwriteBlocked(let path):
            return "A file already exists at '\(path)' and overwrite is disabled."
        case .fileTooLarge(let sizeMB, let limitMB):
            return "Source file (\(sizeMB) MB) exceeds recommended limit (\(limitMB) MB)."
        case .dimensionReadFailed:
            return "Could not read image dimensions."
        case .cancelled:
            return "Conversion was cancelled."
        }
    }
}

// MARK: - Validation Result

/// Result of pre-flight validation for a single conversion job.
enum ValidationResult: Sendable {
    case valid
    case warning(message: String)
    case invalid(message: String)

    var isBlocking: Bool {
        if case .invalid = self { return true }
        return false
    }
}
