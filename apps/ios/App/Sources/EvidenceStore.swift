import Foundation

@MainActor
protocol EvidenceStoring: AnyObject {
    func save(
        data: Data,
        originalFilename: String,
        mediaType: String,
        sourceKind: PaystubSourceKind,
        recognizedText: String?
    ) throws -> PaystubEvidence
    func url(for evidence: PaystubEvidence) -> URL?
    func delete(_ evidence: PaystubEvidence) throws
    func deleteAll() throws
}

@MainActor
final class MemoryEvidenceStore: EvidenceStoring {
    private var blobs: [String: Data] = [:]

    func save(
        data: Data,
        originalFilename: String,
        mediaType: String,
        sourceKind: PaystubSourceKind,
        recognizedText: String?
    ) throws -> PaystubEvidence {
        let fileExtension = URL(fileURLWithPath: originalFilename).pathExtension
        let storedFilename = makeStoredFilename(fileExtension: fileExtension)
        blobs[storedFilename] = data
        return PaystubEvidence(
            storedFilename: storedFilename,
            originalFilename: originalFilename,
            mediaType: mediaType,
            sourceKind: sourceKind,
            recognizedText: recognizedText
        )
    }

    func url(for evidence: PaystubEvidence) -> URL? {
        guard blobs[evidence.storedFilename] != nil else { return nil }
        return URL(fileURLWithPath: "/memory/\(evidence.storedFilename)")
    }

    func delete(_ evidence: PaystubEvidence) throws {
        blobs[evidence.storedFilename] = nil
    }

    func deleteAll() throws {
        blobs.removeAll()
    }

    private func makeStoredFilename(fileExtension: String) -> String {
        fileExtension.isEmpty
            ? UUID().uuidString
            : "\(UUID().uuidString).\(fileExtension.lowercased())"
    }
}

@MainActor
final class LocalEvidenceStore: EvidenceStoring {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        if let baseDirectory {
            directoryURL = baseDirectory
        } else {
            let applicationSupport =
                fileManager.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first ?? fileManager.temporaryDirectory
            directoryURL =
                applicationSupport
                .appendingPathComponent("LinePay", isDirectory: true)
                .appendingPathComponent("Paystubs", isDirectory: true)
        }
    }

    func save(
        data: Data,
        originalFilename: String,
        mediaType: String,
        sourceKind: PaystubSourceKind,
        recognizedText: String?
    ) throws -> PaystubEvidence {
        try ensureDirectory()

        let fileExtension = URL(fileURLWithPath: originalFilename).pathExtension
        let storedFilename = makeStoredFilename(fileExtension: fileExtension)
        let destination = directoryURL.appendingPathComponent(storedFilename, isDirectory: false)
        #if os(iOS)
            try data.write(
                to: destination,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
            try data.write(to: destination, options: [.atomic])
        #endif

        return PaystubEvidence(
            storedFilename: storedFilename,
            originalFilename: originalFilename,
            mediaType: mediaType,
            sourceKind: sourceKind,
            recognizedText: recognizedText
        )
    }

    func url(for evidence: PaystubEvidence) -> URL? {
        guard AppStateValidation.safeFilename(evidence.storedFilename) else { return nil }
        let candidate = directoryURL.appendingPathComponent(
            evidence.storedFilename,
            isDirectory: false
        )
        return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
    }

    func delete(_ evidence: PaystubEvidence) throws {
        guard let url = url(for: evidence) else { return }
        try fileManager.removeItem(at: url)
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    private func ensureDirectory() throws {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        #if os(iOS)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directoryURL.path
            )
        #endif
    }

    private func makeStoredFilename(fileExtension: String) -> String {
        fileExtension.isEmpty
            ? UUID().uuidString
            : "\(UUID().uuidString).\(fileExtension.lowercased())"
    }
}
