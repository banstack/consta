import Foundation

public struct DayTotal: Equatable, Sendable {
    public var day: Date
    public var seconds: TimeInterval
}

public enum SessionHistory {
    /// Focused time on each of the last `days` days, oldest first, ending with today.
    public static func dailyTotals(sessions: [SessionRecord], days: Int = 7, now: Date, calendar: Calendar = .current) -> [DayTotal] {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: TimeInterval] = [:]
        for session in sessions {
            totals[calendar.startOfDay(for: session.start), default: 0] += session.focusedSeconds
        }
        return (0..<days).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { DayTotal(day: $0, seconds: totals[$0] ?? 0) }
        }
    }
}
