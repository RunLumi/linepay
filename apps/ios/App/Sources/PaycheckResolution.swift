import Foundation

/// Worker-recorded follow-up, separate from the immutable calculation and comparison verdict.
enum ResolutionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case reviewing, shared, awaitingResponse, corrected, explained, unresolved
    var id: String { rawValue }
    var title: String {
        switch self {
        case .reviewing: "Reviewing evidence"
        case .shared: "Shared for review"
        case .awaitingResponse: "Awaiting a response"
        case .corrected: "Correction confirmed by me"
        case .explained: "Explanation accepted by me"
        case .unresolved: "Still unresolved"
        }
    }
}

struct ResolutionEvent: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let periodID: UUID
    let paystubID: UUID
    let status: ResolutionStatus
    let note: String
    let recordedEpochSeconds: Int64
}
