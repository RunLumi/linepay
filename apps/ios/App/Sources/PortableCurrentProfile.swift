import Foundation
import LinePayDomain

/// Workspace ownership only. Rules, cadence, timezone and currency remain owned by the period.
struct PortableCurrentProfile: Codable, Hashable, Sendable {
    let periodID: UUID
    let profileID: UUID
    let sourceName: String?

    func profile(in state: AppPersistentState) -> PayProfile? {
        if let active = state.activePeriod, active.id == periodID,
            let zone = active.timeZoneIdentifier
        {
            return PayProfile(
                id: profileID, name: sourceName ?? "Current confirmed pay rules",
                timeZoneIdentifier: zone, agreement: active.agreement,
                preferredCadence: active.window.cadence, baselineAgreement: active.agreement,
                agreementChanges: active.agreementChanges)
        }
        if let closed = state.history.first(where: { $0.id == periodID }),
            let zone = closed.timeZoneIdentifier
        {
            return PayProfile(
                id: profileID, name: sourceName ?? "Current confirmed pay rules",
                timeZoneIdentifier: zone, agreement: closed.agreement,
                preferredCadence: closed.window.cadence, baselineAgreement: closed.agreement,
                agreementChanges: closed.agreementChanges)
        }
        return nil
    }
}
