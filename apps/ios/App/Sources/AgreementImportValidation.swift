import Foundation
import LinePayDomain

enum AgreementImportValidation {
    static func isDigest(_ value: String) -> Bool {
        value.count == 64
            && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    static func validate(_ documents: [ImportedAgreementDocument]) throws {
        guard documents.count <= 64, Set(documents.map(\.id)).count == documents.count else {
            throw invalid()
        }
        for document in documents {
            guard !document.filename.isEmpty, document.filename.count <= 512,
                isDigest(document.sha256), !document.extractionVersion.isEmpty,
                document.extractionVersion.count <= 64,
                (document.extractionNotice?.count ?? 0) <= 2_000,
                (-62_135_596_800...253_402_300_799).contains(document.importedEpochSeconds)
            else { throw invalid() }
            if let evidence = document.evidence {
                guard evidence.mediaType == "application/pdf" else { throw invalid() }
            }
            if let candidates = document.candidates {
                guard let pages = document.pageCount, (1...10_000).contains(pages),
                    candidates.count <= AgreementClauseParser.maximumCandidates,
                    Set(candidates.map(\.id)).count == candidates.count
                else { throw invalid() }
                for candidate in candidates {
                    guard isDigest(candidate.id), (0..<pages).contains(candidate.page),
                        !candidate.quote.isEmpty, candidate.quote.count <= 2_000,
                        (candidate.value?.count ?? 0) <= 100,
                        (candidate.multiplier?.count ?? 0) <= 100,
                        (candidate.reason?.count ?? 0) <= 2_000,
                        candidate.currencyCode.map(PayProfileDraft.supportedCurrencyCodes.contains)
                            ?? true
                    else { throw invalid() }
                    if let confidence = candidate.recognitionConfidence {
                        guard confidence.isFinite, (0...1).contains(confidence) else {
                            throw invalid()
                        }
                    }
                }
                if let review = document.review {
                    guard review.rules.count == candidates.count,
                        Set(review.rules.map(\.candidateID)) == Set(candidates.map(\.id)),
                        Set(review.rules.map(\.candidateID)).count == review.rules.count,
                        review.rules.allSatisfy({
                            $0.value.count <= 100 && $0.multiplier.count <= 100
                        }),
                        PayProfileDraft.supportedCurrencyCodes.contains(review.currencyCode),
                        TimeZone(identifier: review.timeZoneIdentifier) != nil
                    else { throw invalid() }
                    for date in [review.startDate, review.endDate].compactMap({ $0 }) {
                        guard date.timeIntervalSince1970.isFinite,
                            (-62_135_596_800...253_402_300_799).contains(date.timeIntervalSince1970)
                        else { throw invalid() }
                    }
                }
            } else {
                guard document.pageCount == nil, document.review == nil else { throw invalid() }
            }
        }
    }

    static func validate(_ source: AgreementSource) throws {
        guard source.documentID != nil else {
            guard source.documentSHA256 == nil, source.documentPage == nil, source.quotedText == nil
            else {
                throw invalid()
            }
            return
        }
        guard let digest = source.documentSHA256, isDigest(digest),
            let page = source.documentPage, (0..<10_000).contains(page),
            (source.quotedText?.count ?? 0) <= 2_000
        else { throw invalid() }
    }

    private static func invalid() -> LocalStateStoreError { .invalidState }
}
