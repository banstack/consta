import Foundation

/// Lifetime numbers that badges are judged on.
public struct FocusStats: Equatable, Sendable {
    public var sessionCount = 0
    public var longestSessionSeconds: TimeInterval = 0
    public var mostSecondsOnOneLabel: TimeInterval = 0
    public var dayStreak = 0
    public var startedBefore7AM = false
    public var startedAfter11PM = false
    /// True when at least one weekly goal exists and every weekly goal is met this week.
    public var allWeeklyGoalsMet = false

    public init() {}

    public init(sessions: [SessionRecord], goals: [GoalSpec], now: Date, calendar: Calendar = .current) {
        sessionCount = sessions.count
        longestSessionSeconds = sessions.map(\.focusedSeconds).max() ?? 0

        var perLabel: [UUID: TimeInterval] = [:]
        for session in sessions {
            if let id = session.labelID { perLabel[id, default: 0] += session.focusedSeconds }
            let hour = calendar.component(.hour, from: session.start)
            if hour < 7 { startedBefore7AM = true }
            if hour >= 23 { startedAfter11PM = true }
        }
        mostSecondsOnOneLabel = perLabel.values.max() ?? 0
        dayStreak = DayStreak.current(sessions: sessions, now: now, calendar: calendar)

        let weekly = goals.filter { $0.period == .weekly }
        allWeeklyGoalsMet = !weekly.isEmpty && weekly.allSatisfy {
            GoalEvaluator.status(of: $0, sessions: sessions, now: now, calendar: calendar).isMet
        }
    }
}

public struct Badge: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    /// SF Symbol name.
    public let symbol: String
    /// Hex color for the earned medal.
    public let colorHex: String
    public let isEarned: @Sendable (FocusStats) -> Bool
}

public enum BadgeCatalog {
    public static let all: [Badge] = [
        Badge(id: "first-step", name: "First Step", detail: "Finish your first session",
              symbol: "flag.fill", colorHex: "#1F8A3B") { $0.sessionCount >= 1 },
        Badge(id: "deep-diver", name: "Deep Diver", detail: "2h in one session",
              symbol: "water.waves", colorHex: "#0A5AD6") { $0.longestSessionSeconds >= 2 * 3600 },
        Badge(id: "on-fire", name: "On Fire", detail: "5-day streak",
              symbol: "flame.fill", colorHex: "#C25E00") { $0.dayStreak >= 5 },
        Badge(id: "devoted", name: "Devoted", detail: "10h on one label",
              symbol: "books.vertical.fill", colorHex: "#8E3BD1") { $0.mostSecondsOnOneLabel >= 10 * 3600 },
        Badge(id: "early-bird", name: "Early Bird", detail: "Start before 7 AM",
              symbol: "sunrise.fill", colorHex: "#B8860B") { $0.startedBefore7AM },
        Badge(id: "night-owl", name: "Night Owl", detail: "Start after 11 PM",
              symbol: "moon.stars.fill", colorHex: "#3A3F9E") { $0.startedAfter11PM },
        Badge(id: "week-warrior", name: "Week Warrior", detail: "Every weekly goal met",
              symbol: "shield.fill", colorHex: "#A31F14") { $0.allWeeklyGoalsMet },
        Badge(id: "centurion", name: "Centurion", detail: "100 sessions",
              symbol: "rosette", colorHex: "#5C5C66") { $0.sessionCount >= 100 },
        Badge(id: "marathon", name: "Marathon", detail: "30-day streak",
              symbol: "figure.run", colorHex: "#0E7C86") { $0.dayStreak >= 30 },
    ]

    public static func badge(id: String) -> Badge? {
        all.first { $0.id == id }
    }
}
