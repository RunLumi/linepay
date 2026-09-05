import Foundation

/// Owns a single import from the first asynchronous read through saved-source OCR.
/// Tokens prevent a cancelled operation from finishing or replacing a newer review.
struct PaystubImportOperation: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case idle
        case loading
        case readingSavedOriginal
    }

    private(set) var phase: Phase = .idle
    private var token: UUID?

    var isProcessing: Bool { token != nil }
    var message: String {
        switch phase {
        case .idle: ""
        case .loading: "Preparing paystub input. Not saved yet."
        case .readingSavedOriginal: "Reading on this iPhone. Original saved."
        }
    }

    mutating func begin() -> UUID? {
        guard token == nil else { return nil }
        let newToken = UUID()
        token = newToken
        phase = .loading
        return newToken
    }

    func owns(_ candidate: UUID) -> Bool { token == candidate }

    mutating func didSaveOriginal(_ candidate: UUID) {
        guard owns(candidate) else { return }
        phase = .readingSavedOriginal
    }

    mutating func finish(_ candidate: UUID) {
        guard owns(candidate) else { return }
        cancel()
    }

    mutating func cancel() {
        token = nil
        phase = .idle
    }
}
