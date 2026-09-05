import Foundation
import PDFKit
import UIKit
import Vision

enum PaystubOCRError: LocalizedError {
    case unsupportedDocument
    case noReadablePages

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            "LinePaycheck could not open this document. You can still enter the paycheck manually."
        case .noReadablePages:
            "LinePaycheck could not find readable text. You can still enter the paycheck manually."
        }
    }
}

struct PaystubOCRService: Sendable {
    func recognize(data: Data, fileExtension: String) async throws -> OCRPaystubResult {
        try await Task.detached(priority: .userInitiated) {
            let images = try Self.images(from: data, fileExtension: fileExtension)
            guard !images.isEmpty else {
                throw PaystubOCRError.noReadablePages
            }

            var lines: [String] = []
            for image in images {
                lines += try Self.recognizeLines(in: image)
            }
            guard !lines.isEmpty else {
                throw PaystubOCRError.noReadablePages
            }

            return PaystubTextParser.parse(lines: lines)
        }.value
    }

    private static func images(from data: Data, fileExtension: String) throws -> [CGImage] {
        if fileExtension.lowercased() == "pdf" || data.starts(with: Data("%PDF".utf8)) {
            guard let document = PDFDocument(data: data) else {
                throw PaystubOCRError.unsupportedDocument
            }

            return (0..<min(document.pageCount, 8)).compactMap { index in
                guard let page = document.page(at: index) else { return nil }
                let thumbnail = page.thumbnail(
                    of: CGSize(width: 1_800, height: 2_400),
                    for: .mediaBox
                )
                return normalizedCGImage(from: thumbnail)
            }
        }

        guard let image = UIImage(data: data), let cgImage = normalizedCGImage(from: image) else {
            throw PaystubOCRError.unsupportedDocument
        }
        return [cgImage]
    }

    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.cgImage
    }

    private static func recognizeLines(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        return observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
    }

}
