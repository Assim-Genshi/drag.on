import Testing
import Foundation
@testable import drag_on

struct drag_onTests {

    @Test func testImageFormatMetadata() async throws {
        // Test file extension mappings
        #expect(ImageFormat.webp.fileExtension == "webp")
        #expect(ImageFormat.png.fileExtension == "png")
        #expect(ImageFormat.jpg.fileExtension == "jpg")
        #expect(ImageFormat.icns.fileExtension == "icns")
        #expect(ImageFormat.ico.fileExtension == "ico")
        #expect(ImageFormat.pdf.fileExtension == "pdf")

        // Test quality slider support
        #expect(ImageFormat.webp.supportsQuality == true)
        #expect(ImageFormat.jpg.supportsQuality == true)
        #expect(ImageFormat.png.supportsQuality == false)
        #expect(ImageFormat.icns.supportsQuality == false)
        #expect(ImageFormat.ico.supportsQuality == false)
        #expect(ImageFormat.pdf.supportsQuality == false)

        // Test descriptions are present
        for format in ImageFormat.allCases {
            #expect(!format.formatDescription.isEmpty)
        }
    }

    @Test func testConversionErrorDescriptions() async throws {
        let error = ConversionError.unsupportedInput(extension: "xyz")
        #expect(error.localizedDescription.contains(".xyz"))
        #expect(error.errorDescription?.contains("xyz") == true)
    }

    @Test func testConversionValidatorValidation() async throws {
        let validator = ConversionValidator()

        // 1. Test non-existent file validation
        let tempDir = FileManager.default.temporaryDirectory
        let bogusFile = tempDir.appendingPathComponent("non_existent_\(UUID().uuidString).png")
        let job = ConversionJob(
            sourceURL: bogusFile,
            fileName: bogusFile.lastPathComponent,
            outputDirectory: tempDir,
            format: .webp,
            quality: 0.8
        )

        let result = validator.validate(job: job)
        if case .invalid(let message) = result {
            #expect(message.contains("Source file not found"))
        } else {
            Issue.record("Expected .invalid result for non-existent file, got \(result)")
        }
    }
}
