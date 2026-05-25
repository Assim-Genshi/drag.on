import Foundation

/// Protocol for format conversion strategies.
/// Each format implements its own converter conforming to this protocol.
protocol FormatConverting: Sendable {
    /// The output format this converter handles.
    var format: ImageFormat { get }

    /// Convert a source file to the destination path.
    /// - Parameters:
    ///   - source: The input file URL (guaranteed to exist and be readable).
    ///   - destination: The output file URL (directory guaranteed to exist).
    ///   - quality: Quality setting (0.0–1.0). Ignored by lossless formats.
    /// - Throws: `ConversionError` on failure.
    func convert(source: URL, destination: URL, quality: Double) throws
}
