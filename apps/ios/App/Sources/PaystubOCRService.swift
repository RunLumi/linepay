import Foundation
import ImageIO
import LinePayDomain
import PDFKit
import UIKit
import Vision

struct OCRPaystubResult: Sendable {
    let recognizedText: String
    let suggestions: [PaystubField: OCRFieldSuggestion]
    let pageCount: Int
    let notice: String?
}

enum PaystubOCRError: LocalizedError {
    case unsupportedDocument, noReadablePages, oversizedDocument
    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            "This document could not be opened. The original is kept; enter the numbers manually."
        case .noReadablePages:
            "No readable text was found. The original is kept; enter the numbers manually."
        case .oversizedDocument: "Choose a document up to 25 MB."
        }
    }
}

struct PaystubOCRService: Sendable {
    func recognize(data: Data, fileExtension: String) async throws -> OCRPaystubResult {
        guard data.count <= 25 * 1024 * 1024 else { throw PaystubOCRError.oversizedDocument }
        let task = Task.detached(priority: .userInitiated) {
            var lines: [RecognizedPaystubLine] = []
            let pageCount: Int
            if fileExtension.lowercased() == "pdf" || data.starts(with: Data("%PDF".utf8)) {
                guard let pdf = PDFDocument(data: data), !pdf.isLocked else {
                    throw PaystubOCRError.unsupportedDocument
                }
                pageCount = pdf.pageCount
                // Render one page at a time, not eight high-resolution images at once.
                for index in 0..<min(pageCount, 8) {
                    try Task.checkCancellation()
                    let pageLines = try autoreleasepool { () throws -> [RecognizedPaystubLine] in
                        guard let page = pdf.page(at: index),
                            let image = Self.normalizedImage(
                                page.thumbnail(
                                    of: CGSize(width: 1400, height: 1900), for: .mediaBox))
                        else { return [] }
                        return try Self.recognizeLines(image, page: index)
                    }
                    lines += pageLines
                }
            } else {
                pageCount = 1
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                    let normalized = CGImageSourceCreateThumbnailAtIndex(
                        source, 0,
                        [
                            kCGImageSourceCreateThumbnailFromImageAlways: true,
                            kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 2400,
                            kCGImageSourceShouldCacheImmediately: true,
                        ] as CFDictionary)
                else {
                    throw PaystubOCRError.unsupportedDocument
                }
                lines = try Self.recognizeLines(normalized, page: 0)
            }
            guard !lines.isEmpty else { throw PaystubOCRError.noReadablePages }
            return OCRPaystubResult(
                recognizedText: lines.map(\.text).joined(separator: "\n"),
                suggestions: PaystubTextParser.parse(lines), pageCount: pageCount,
                notice: pageCount > 8
                    ? "Only the first 8 of \(pageCount) pages were read. Review the remaining original pages; this audit is limited."
                    : nil)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func normalizedImage(_ image: UIImage) -> CGImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let factor = min(1, 2400 / max(size.width, size.height))
        let target = CGSize(width: size.width * factor, height: size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }.cgImage
    }

    private static func recognizeLines(_ image: CGImage, page: Int) throws
        -> [RecognizedPaystubLine]
    {
        try Task.checkCancellation()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return RecognizedPaystubLine(
                text: candidate.string,
                region: SourceRegion(
                    page: page, x: box.origin.x, y: box.origin.y,
                    width: box.width, height: box.height), confidence: Double(candidate.confidence))
        }
    }
}
