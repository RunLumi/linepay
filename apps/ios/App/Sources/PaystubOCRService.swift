import Foundation
import PDFKit
import UIKit
import Vision

struct OCRPaystubResult: Sendable {
    let recognizedText: String
    let grossPay: String?
    let regularPay: String?
    let overtimePay: String?
    let doubleTimePay: String?
    let perDiemPay: String?
}

enum PaystubOCRError: LocalizedError {
    case unsupportedDocument
    case noReadablePages

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            "LinePay could not open this document. You can still enter the paycheck manually."
        case .noReadablePages:
            "LinePay could not find readable text. You can still enter the paycheck manually."
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

            return OCRPaystubResult(
                recognizedText: lines.joined(separator: "\n"),
                grossPay: Self.amount(in: lines, labels: ["gross pay", "gross earnings", "gross"]),
                regularPay: Self.amount(in: lines, labels: ["regular pay", "regular"]),
                overtimePay: Self.amount(in: lines, labels: ["overtime", "ot pay"]),
                doubleTimePay: Self.amount(
                    in: lines,
                    labels: ["double time", "double-time", "dt pay"]
                ),
                perDiemPay: Self.amount(in: lines, labels: ["per diem", "per-diem"])
            )
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

    private static func amount(in lines: [String], labels: [String]) -> String? {
        for line in lines {
            let lowercased = line.lowercased()
            guard labels.contains(where: { lowercased.contains($0) }) else { continue }
            if let value = lastCurrencyLikeNumber(in: line) {
                return value
            }
        }
        return nil
    }

    private static func lastCurrencyLikeNumber(in line: String) -> String? {
        let pattern = #"\$?([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)\.([0-9]{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.matches(in: line, range: range).last,
            let matchRange = Range(match.range, in: line)
        else {
            return nil
        }
        return line[matchRange]
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
    }
}
