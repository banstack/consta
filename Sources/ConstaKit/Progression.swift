import Foundation

public struct GoalBonus: Equatable, Sendable {
    public let goalID: UUID
    public let period: GoalPeriod
    public let key: String
    public let xp: Int
}

/// Everything a finished session earns, worked out before it is saved so the
/// user can see it and still discard the session.
public struct SessionOutcome: Equatable, Sendable {
    public let focusXP: Int
    public let goalBonuses: [GoalBonus]
    public let newBadgeIDs: [String]
    public let levelBefore: LevelProgress
    public let levelAfter: LevelProgress

    public var totalXP: Int { focusXP + goalBonuses.reduce(0) { $0 + $1.xp } }
    public var leveledUp: Bool { levelAfter.level > levelBefore.level }
}

public enum Progression {
    public static func evaluate(
        newSession: SessionRecord,
        pastSessions: [SessionRecord],
        goals: [GoalSpec],
        paidBonusKeys: Set<String>,
        unlockedBadgeIDs: Set<String>,
        currentXP: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> SessionOutcome {
        let sessions = pastSessions + [newSession]
        let focusXP = XPRules.focusXP(seconds: newSession.focusedSeconds)

        let bonuses = goals
            .filter { $0.labelID == newSession.labelID }
            .map { GoalEvaluator.status(of: $0, sessions: sessions, now: now, calendar: calendar) }
            .filter { $0.isMet && !paidBonusKeys.contains($0.bonusKey) }
            .map { GoalBonus(goalID: $0.goal.id, period: $0.goal.period, key: $0.bonusKey, xp: $0.goal.period.bonusXP) }

        let stats = FocusStats(sessions: sessions, goals: goals, now: now, calendar: calendar)
        let newBadges = BadgeCatalog.all
            .filter { !unlockedBadgeIDs.contains($0.id) && $0.isEarned(stats) }
            .map(\.id)

        let gained = focusXP + bonuses.reduce(0) { $0 + $1.xp }
        return SessionOutcome(
            focusXP: focusXP,
            goalBonuses: bonuses,
            newBadgeIDs: newBadges,
            levelBefore: Leveling.progress(totalXP: currentXP),
            levelAfter: Leveling.progress(totalXP: currentXP + gained)
        )
    }
}
