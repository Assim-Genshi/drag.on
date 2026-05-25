import Foundation
import os
import ImageIO

/// Actor-based conversion queue that processes jobs sequentially.
///
/// Each conversion batch gets a fresh queue instance to prevent state leakage.
/// Jobs are processed one at a time to avoid overwhelming the system with
/// parallel `sips`/`iconutil` subprocesses.
actor ConversionQueue {

    // MARK: - State

    private var isCancelled = false
    private let converter: ConversionEngine
    private let validator: ConversionValidator
    private let svgRasterizer: SVGRasterizer

    /// Stream continuation for broadcasting progress updates.
    private var progressContinuation: AsyncStream<ConversionProgress>.Continuation?

    // MARK: - Initialization

    init() {
        self.converter = ConversionEngine()
        self.validator = ConversionValidator()
        self.svgRasterizer = SVGRasterizer()
    }

    // MARK: - Public API

    /// Process a batch of conversion jobs sequentially.
    ///
    /// - Parameters:
    ///   - jobs: Array of conversion jobs to process.
    ///   - onProgress: Closure called on the MainActor for each progress update.
    /// - Returns: Array of successful conversion results.
    /// - Throws: If all jobs fail, throws the collected error message.
    func process(
        jobs: [ConversionJob],
        onProgress: @Sendable @MainActor (ConversionProgress) -> Void
    ) async throws -> [ConversionResult] {
        guard !jobs.isEmpty else { return [] }

        Logger.conversionQueue.info("Starting conversion queue with \(jobs.count) job(s)")

        // Phase 1: Validate all jobs
        let validationResults = validator.validate(jobs: jobs)
        var validJobs: [ConversionJob] = []
        var warnings: [String] = []

        for (index, result) in validationResults.enumerated() {
            switch result {
            case .valid:
                validJobs.append(jobs[index])
            case .warning(let message):
                Logger.conversionQueue.warning("Validation warning for \(jobs[index].fileName): \(message)")
                warnings.append(message)
                validJobs.append(jobs[index])
            case .invalid(let message):
                Logger.conversionQueue.error("Validation failed for \(jobs[index].fileName): \(message)")
            }
        }

        guard !validJobs.isEmpty else {
            let invalidMessages = validationResults.compactMap { result -> String? in
                if case .invalid(let msg) = result { return msg }
                return nil
            }
            throw ConversionError.outputNotCreated(detail: invalidMessages.joined(separator: "\n"))
        }

        // Phase 2: Process each job sequentially
        var results: [ConversionResult] = []
        var errors: [String] = []

        for (index, job) in validJobs.enumerated() {
            // Check cancellation
            guard !isCancelled, !Task.isCancelled else {
                Logger.conversionQueue.info("Conversion queue cancelled at job \(index + 1)/\(validJobs.count)")
                throw ConversionError.cancelled
            }

            let progress = ConversionProgress(
                currentFileName: job.fileName,
                currentIndex: index,
                totalCount: validJobs.count,
                phase: .converting
            )
            await onProgress(progress)

            do {
                let result = try await processJob(job, index: index, total: validJobs.count, onProgress: onProgress)
                results.append(result)
                Logger.conversionQueue.info("✓ Converted \(job.fileName) → .\(job.format.fileExtension)")
            } catch {
                let message = "\(job.fileName): \(error.localizedDescription)"
                Logger.conversionQueue.error("✗ Failed \(job.fileName): \(error.localizedDescription)")
                errors.append(message)
            }
        }

        Logger.conversionQueue.info("Queue complete: \(results.count) succeeded, \(errors.count) failed")

        if results.isEmpty && !errors.isEmpty {
            throw ConversionError.outputNotCreated(detail: errors.joined(separator: "\n"))
        }

        return results
    }

    /// Cancel all pending jobs.
    func cancel() {
        isCancelled = true
        Logger.conversionQueue.info("Conversion queue cancellation requested")
    }

    // MARK: - Job Processing

    /// Process a single conversion job, handling SVG rasterization and overwrite policies.
    private func processJob(
        _ job: ConversionJob,
        index: Int,
        total: Int,
        onProgress: @Sendable @MainActor (ConversionProgress) -> Void
    ) async throws -> ConversionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        var effectiveSource = job.sourceURL
        var tempSVGRaster: URL? = nil

        // SVG pre-processing: rasterize to temporary PNG (except for PDF which preserves vectors)
        let isSVG = job.sourceURL.pathExtension.lowercased() == "svg"
        if isSVG && job.format != .pdf {
            let rasterProgress = ConversionProgress(
                currentFileName: job.fileName,
                currentIndex: index,
                totalCount: total,
                phase: .rasterizing
            )
            await onProgress(rasterProgress)

            let rasterURL = try svgRasterizer.rasterize(svgURL: job.sourceURL)
            tempSVGRaster = rasterURL
            effectiveSource = rasterURL
        }

        defer {
            // Clean up temporary SVG raster
            if let tempURL = tempSVGRaster {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }

        // Resolve destination path with overwrite handling
        let destinationURL = try resolveDestination(for: job)

        // Convert
        let convertProgress = ConversionProgress(
            currentFileName: job.fileName,
            currentIndex: index,
            totalCount: total,
            phase: .converting
        )
        await onProgress(convertProgress)

        try converter.convert(
            source: effectiveSource,
            destination: destinationURL,
            format: job.format,
            quality: job.quality,
            isSVGSource: isSVG
        )

        // Verify output
        let verifyProgress = ConversionProgress(
            currentFileName: job.fileName,
            currentIndex: index,
            totalCount: total,
            phase: .verifying
        )
        await onProgress(verifyProgress)

        try verifyOutput(at: destinationURL, format: job.format)

        // Get file size
        let fileSize = fileSizeAt(destinationURL)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        return ConversionResult(
            originalURL: job.sourceURL,
            convertedURL: destinationURL,
            format: job.format,
            fileSize: fileSize,
            duration: duration
        )
    }

    // MARK: - Overwrite Handling

    /// Resolve the destination URL, handling overwrite policies.
    private func resolveDestination(for job: ConversionJob) throws -> URL {
        let baseName = job.sourceURL.deletingPathExtension().lastPathComponent
        let ext = job.format.fileExtension
        let baseURL = job.outputDirectory.appendingPathComponent("\(baseName).\(ext)")

        let fm = FileManager.default

        guard fm.fileExists(atPath: baseURL.path) else {
            return baseURL
        }

        switch job.overwritePolicy {
        case .overwrite:
            try? fm.removeItem(at: baseURL)
            return baseURL

        case .skip:
            throw ConversionError.overwriteBlocked(path: baseURL.path)

        case .autoRename:
            return generateUniquePath(base: baseName, ext: ext, directory: job.outputDirectory)
        }
    }

    /// Generate a unique file path by appending (1), (2), etc.
    private func generateUniquePath(base: String, ext: String, directory: URL) -> URL {
        let fm = FileManager.default
        var counter = 1
        var candidate: URL

        repeat {
            candidate = directory.appendingPathComponent("\(base) (\(counter)).\(ext)")
            counter += 1
        } while fm.fileExists(atPath: candidate.path) && counter < 1000

        return candidate
    }

    // MARK: - Output Verification

    /// Verify that the converted output file is valid.
    private func verifyOutput(at url: URL, format: ImageFormat) throws {
        let fm = FileManager.default

        // 1. File must exist
        guard fm.fileExists(atPath: url.path) else {
            throw ConversionError.outputVerificationFailed(
                path: url.path,
                detail: "Output file does not exist."
            )
        }

        // 2. File size must be > 0
        let size = fileSizeAt(url)
        guard size > 0 else {
            throw ConversionError.outputVerificationFailed(
                path: url.path,
                detail: "Output file is empty (0 bytes)."
            )
        }

        // 3. Format-specific validation
        switch format {
        case .webp, .png, .jpg:
            // Try to create an image source — validates the file is a loadable image
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  CGImageSourceGetCount(source) > 0 else {
                throw ConversionError.outputVerificationFailed(
                    path: url.path,
                    detail: "File is not a valid \(format.rawValue) image."
                )
            }

        case .icns:
            // ICNS files start with 'icns' magic bytes
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  data.count >= 4,
                  String(data: data.prefix(4), encoding: .ascii) == "icns" else {
                throw ConversionError.outputVerificationFailed(
                    path: url.path,
                    detail: "File does not have valid ICNS header."
                )
            }

        case .ico:
            // ICO files start with 00 00 01 00 header
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  data.count >= 4,
                  data[0] == 0x00, data[1] == 0x00,
                  data[2] == 0x01, data[3] == 0x00 else {
                throw ConversionError.outputVerificationFailed(
                    path: url.path,
                    detail: "File does not have valid ICO header."
                )
            }

        case .pdf:
            // PDF files start with %PDF
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  data.count >= 4,
                  String(data: data.prefix(4), encoding: .ascii) == "%PDF" else {
                throw ConversionError.outputVerificationFailed(
                    path: url.path,
                    detail: "File does not have valid PDF header."
                )
            }
        }

        Logger.conversionQueue.debug("Output verified: \(url.lastPathComponent) (\(size) bytes)")
    }

    /// Get the file size in bytes.
    private func fileSizeAt(_ url: URL) -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }
}
