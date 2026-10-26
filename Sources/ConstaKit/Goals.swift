import Foundation

public struct GoalStatus: Equatable, Sendable {
    public let goal: GoalSpec
    public let interval: DateInterval
    public let focusedSeconds: TimeInterval
    /// Consecutive periods met, counting the current one only once it is met.
    public let streak: Int

    public var isMet: Bool { focusedSeconds >= goal.targetSeconds }
    public var fraction: Double { min(1, focusedSeconds / max(1, goal.targetSeconds)) }
    public var remainingSeconds: TimeInterval { max(0, goal.targetSeconds - focusedSeconds) }

    /// Stable key for the bonus paid when this period's goal is met, so it is paid once.
    public var bonusKey: String {
        "goal:\(goal.id.uuidString):\(Int(interval.start.timeIntervalSince1970))"
    }
}

public enum GoalEvaluator {
    /// Sessions count toward the period they started in.
    public static func status(
        of goal: GoalSpec,
        sessions: [SessionRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> GoalStatus {
        var totals: [Date: TimeInterval] = [:]
        for session in sessions where session.labelID == goal.labelID {
            let start = goal.period.interval(containing: session.start, calendar: calendar).start
            totals[start, default: 0] += session.focusedSeconds
        }

        let current = goal.period.interval(containing: now, calendar: calendar)
        let currentSeconds = totals[current.start] ?? 0

        var streak = 0
        var cursor = currentSeconds >= goal.targetSeconds
            ? current
            : goal.period.interval(before: current, calendar: calendar)
        while (totals[cursor.start] ?? 0) >= goal.targetSeconds {
            streak += 1
            cursor = goal.period.interval(before: cursor, calendar: calendar)
        }

        return GoalStatus(goal: goal, interval: current, focusedSeconds: currentSeconds, streak: streak)
    }
}

public enum DayStreak {
    /// Consecutive days with at least one session, ending today, or yesterday if
    /// nothing has been logged yet today (so the streak isn't "lost" at midnight).
    public static func current(sessions: [SessionRecord], now: Date, calendar: Calendar = .current) -> Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.start) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }
}
