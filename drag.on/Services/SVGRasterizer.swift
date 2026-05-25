import Cocoa
import os

/// Rasterizes SVG files to PNG bitmaps for downstream conversion.
///
/// macOS natively handles SVG via `NSImage`, so we load the SVG,
/// render it to a `CGBitmapContext` at the target size, and write
/// a temporary PNG that the conversion pipeline consumes.
struct SVGRasterizer: Sendable {

    /// Default rasterization target: 2048×2048 maximum dimension (preserving aspect ratio).
    static let defaultMaxDimension: Int = 2048

    // MARK: - Public API

    /// Rasterize an SVG file to a temporary PNG file.
    ///
    /// - Parameters:
    ///   - svgURL: Path to the source `.svg` file.
    ///   - maxDimension: Maximum width or height of the output bitmap.
    /// - Returns: URL of the temporary PNG file. Caller is responsible for cleanup.
    /// - Throws: `ConversionError.svgRasterizationFailed` on failure.
    func rasterize(svgURL: URL, maxDimension: Int = defaultMaxDimension) throws -> URL {
        Logger.converter.info("Rasterizing SVG: \(svgURL.lastPathComponent) at max \(maxDimension)px")

        // Load SVG via NSImage — macOS renders SVG natively
        guard let svgImage = NSImage(contentsOf: svgURL) else {
            throw ConversionError.svgRasterizationFailed(
                detail: "Failed to load SVG file. The file may be corrupted or contain unsupported elements."
            )
        }

        // Get the natural SVG size
        let originalSize = svgImage.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            throw ConversionError.svgRasterizationFailed(
                detail: "SVG has zero dimensions (\(originalSize.width)×\(originalSize.height))."
            )
        }

        // Calculate target size preserving aspect ratio
        let targetSize = calculateTargetSize(original: originalSize, maxDimension: CGFloat(maxDimension))

        // Render to bitmap
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bytesPerPixel = 4
        let stride = width * bytesPerPixel

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ConversionError.svgRasterizationFailed(detail: "Failed to create bitmap context.")
        }

        // Draw the SVG into the context
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        let drawRect = NSRect(origin: .zero, size: targetSize)
        svgImage.draw(in: drawRect)

        NSGraphicsContext.restoreGraphicsState()

        // Extract CGImage
        guard let cgImage = context.makeImage() else {
            throw ConversionError.svgRasterizationFailed(detail: "Failed to render SVG to bitmap.")
        }

        // Write to temporary PNG file
        let tempDir = FileManager.default.temporaryDirectory
        let tempPNG = tempDir.appendingPathComponent("dragon_svg_\(UUID().uuidString).png")

        guard let destination = CGImageDestinationCreateWithURL(tempPNG as CFURL, "public.png" as CFString, 1, nil) else {
            throw ConversionError.svgRasterizationFailed(detail: "Failed to create PNG destination.")
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.svgRasterizationFailed(detail: "Failed to write PNG file.")
        }

        Logger.converter.info("SVG rasterized to \(width)×\(height) PNG: \(tempPNG.lastPathComponent)")
        return tempPNG
    }

    // MARK: - Helpers

    /// Calculate target size preserving aspect ratio within the max dimension.
    private func calculateTargetSize(original: NSSize, maxDimension: CGFloat) -> NSSize {
        let maxSide = max(original.width, original.height)
        guard maxSide > maxDimension else {
            // SVG is smaller than max — use original size, but ensure minimum 1px
            return NSSize(
                width: max(1, original.width),
                height: max(1, original.height)
            )
        }

        let scale = maxDimension / maxSide
        return NSSize(
            width: max(1, round(original.width * scale)),
            height: max(1, round(original.height * scale))
        )
    }
}
