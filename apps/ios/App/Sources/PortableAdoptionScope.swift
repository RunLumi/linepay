import Foundation

/// Source-backed uncertainty is scoped to the copied financial context, never a global waiver.
enum PortableAdoptionScope {
    static func note(document: PortableState, snapshot: PortableWorkSnapshot) -> String {
        // Each explicit adoption creates fresh local work IDs. Follow only its typed
        // source context so uncertainty cannot disappear on a second platform hop.
        var contexts = [snapshot]
        var visited = Set([snapshot.id])
        var index = 0
        while index < contexts.count {
            let context = contexts[index]
            index += 1
            for adoption in document.adoptions
            where adoption.adoptedProfileRef == context.profileRef {
                guard
                    adoption.adoptedWorkSnapshotRef == context.id
                        || (context.periodRef != nil
                            && adoption.adoptedPeriodRef == context.periodRef),
                    let source = document.workSnapshots.first(where: {
                        $0.id == adoption.sourceWorkSnapshotRef
                    }),
                    visited.insert(source.id).inserted
                else { continue }
                contexts.append(source)
            }
        }
        return document.paycheckReceipts.compactMap { receipt -> String? in
            guard receipt.reviewFacts.weeklyReviewPending == true,
                let original = document.workSnapshots.first(where: {
                    $0.id == receipt.workSnapshotRef
                }),
                contexts.contains(where: { context in
                    context.profileRef == original.profileRef
                        && ((context.periodRef != nil && receipt.periodRef == context.periodRef)
                            || !Set(context.work.map(\.id)).isDisjoint(
                                with: Set(original.work.map(\.id))))
                })
            else { return nil }
            return
                "Unresolved weekly review inherited from imported receipt \(receipt.id), period \(receipt.periodRef ?? "not recorded"), work snapshot \(receipt.workSnapshotRef); copied source snapshot \(snapshot.id). Confirming configured rules does not establish complete workweek coverage or map weekly premiums into this paycheck."
        }.joined(separator: "\n")
    }

    static func currentSource(_ document: PortableState) -> (PortableProfile, PortableWorkSnapshot)?
    {
        if let period = document.periods.first(where: { $0.isCurrent == true }),
            let ref = period.currentWorkSnapshotRef,
            let snapshot = document.workSnapshots.first(where: { $0.id == ref }),
            let profile = document.profiles.first(where: { $0.id == snapshot.profileRef })
        {
            return (profile, snapshot)
        }
        guard let profile = document.profiles.first(where: { $0.id == document.activeProfileRef }),
            let snapshot = document.workSnapshots.first(where: {
                $0.id == profile.currentWorkSnapshotRef
            })
        else { return nil }
        return (profile, snapshot)
    }
}
