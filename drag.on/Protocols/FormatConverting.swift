import Foundation

/// Protocol for format conversion, making it easy to add new converters.
protocol FormatConverting: Sendable {
    var format: ImageFormat { get }
    func convert(source: URL, destination: URL) async throws
}
