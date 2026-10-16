import CryptoKit
import Foundation
import PDFKit
import UIKit

/// Local document understanding only. Original bytes are retained separately before extraction.
struct AgreementDocumentService: Sendable {
    static let maximumBytes = 25 * 1_024 * 1_024
    static let maximumPagesRead = 128

    static func read(_ url: URL) async throws -> Data {
        let task = Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let stream = InputStream(url: url) else { throw CocoaError(.fileReadUnknown) }
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
            while true {
                try Task.checkCancellation()
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count < 0 { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
                if count == 0 { break }
                guard data.count + count <= maximumBytes else {
                    throw PaystubOCRError.oversizedDocument
                }
                data.append(contentsOf: buffer.prefix(count))
            }
            return data
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func verifiedURL(_ url: URL, sha256: String, page: Int) async throws -> URL {
        let data = try await read(url)
        return try await Task.detached(priority: .userInitiated) {
            guard Self.digest(data) == sha256, let pdf = PDFDocument(data: data), !pdf.isLocked,
                (0..<pdf.pageCount).contains(page)
            else { throw CocoaError(.fileReadCorruptFile) }
            return url
        }.value
    }

    func extract(_ data: Data) async throws -> AgreementExtraction {
        guard !data.isEmpty, data.count <= Self.maximumBytes else {
            throw PaystubOCRError.oversizedDocument
        }
        let task = Task.detached(priority: .userInitiated) {
            guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount > 0 else {
                throw PaystubOCRError.unsupportedDocument
            }
            var lines: [AgreementTextLine] = []
            var characters = 0
            var incomplete = pdf.pageCount > Self.maximumPagesRead
            for index in 0..<min(pdf.pageCount, Self.maximumPagesRead) {
                try Task.checkCancellation()
                let pageLines = try autoreleasepool { () throws -> [AgreementTextLine] in
                    guard let page = pdf.page(at: index) else { return [] }
                    if page.numberOfCharacters > 100_000 { return [] }
                    if let text = page.string,
                        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    {
                        return text.split(whereSeparator: \.isNewline).map {
                            AgreementTextLine(text: String($0), page: index, confidence: nil)
                        }
                    }
                    guard
                        let image = page.thumbnail(
                            of: CGSize(width: 1400, height: 1900), for: .mediaBox
                        ).cgImage
                    else { return [] }
                    return try PaystubOCRService.recognizeLines(image, page: index).map {
                        AgreementTextLine(text: $0.text, page: index, confidence: $0.confidence)
                    }
                }
                if pageLines.isEmpty { incomplete = true }
                characters += pageLines.reduce(0) { $0 + $1.text.count }
                if characters > 250_000 {
                    incomplete = true
                    break
                }
                lines += pageLines
            }
            let candidates = AgreementClauseParser.parse(lines)
            if candidates.count == AgreementClauseParser.maximumCandidates { incomplete = true }
            let notice: String?
            if incomplete {
                notice =
                    "Reading was limited to 128 pages, 250,000 characters and 64 candidate clauses. Unread or omitted clauses remain unverified; review the complete original."
            } else if candidates.isEmpty {
                notice =
                    "No supported candidate clauses were found. Keep the original and enter confirmed rules manually."
            } else {
                notice = nil
            }
            return AgreementExtraction(
                pageCount: pdf.pageCount, candidates: candidates, notice: notice)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
