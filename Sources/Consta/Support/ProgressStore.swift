import ConstaKit
import Foundation
import SwiftData

/// Reads and writes the game state (XP, goal bonuses, badges) in SwiftData.
@MainActor
enum ProgressStore {
    static func totalXP(_ context: ModelContext) -> Int {
        let events = (try? context.fetch(FetchDescriptor<XPEvent>())) ?? []
        return events.reduce(0) { $0 + $1.amount }
    }

    static func sessionRecords(_ context: ModelContext) -> [SessionRecord] {
        ((try? context.fetch(FetchDescriptor<FocusSession>())) ?? []).map(\.record)
    }

    static func goalSpecs(_ context: ModelContext) -> [GoalSpec] {
        ((try? context.fetch(FetchDescriptor<Goal>())) ?? []).compactMap(\.spec)
    }

    /// What saving `finished` would earn, without saving anything.
    static func preview(_ finished: FinishedSession, context: ModelContext, now: Date = .now) -> SessionOutcome {
        let paidKeys = Set(((try? context.fetch(FetchDescriptor<XPEvent>())) ?? []).map(\.key))
        let unlocked = Set(((try? context.fetch(FetchDescriptor<BadgeUnlock>())) ?? []).map(\.badgeID))
        return Progression.evaluate(
            newSession: finished.record,
            pastSessions: sessionRecords(context),
            goals: goalSpecs(context),
            paidBonusKeys: paidKeys,
            unlockedBadgeIDs: unlocked,
            currentXP: totalXP(context),
            now: now
        )
    }

    static func save(_ finished: FinishedSession, outcome: SessionOutcome, note: String, context: ModelContext) {
        let labelID = finished.session.labelID
        let label = try? context.fetch(FetchDescriptor<ActivityLabel>(predicate: #Predicate { $0.id == labelID })).first
        let session = FocusSession(
            label: label,
            start: finished.session.start,
            end: finished.end,
            focusedSeconds: finished.focusedSeconds,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            xp: outcome.totalXP
        )
        context.insert(session)

        if outcome.focusXP > 0 {
            context.insert(XPEvent(key: "session:\(session.id.uuidString)", amount: outcome.focusXP, reason: "Focus time"))
        }
        for bonus in outcome.goalBonuses {
            let name = label?.name ?? "Goal"
            let reason = bonus.period == .daily ? "Daily \(name) goal met" : "Weekly \(name) goal met"
            context.insert(XPEvent(key: bonus.key, amount: bonus.xp, reason: reason))
        }
        for badgeID in outcome.newBadgeIDs {
            context.insert(BadgeUnlock(badgeID: badgeID))
        }
        try? context.save()
    }
}
