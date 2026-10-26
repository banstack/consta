import Foundation

/// A finished focus session, as the game logic sees it.
public struct SessionRecord: Equatable, Sendable {
    public var labelID: UUID?
    public var start: Date
    public var end: Date
    /// Time actually focused, which excludes pauses.
    public var focusedSeconds: TimeInterval

    public init(labelID: UUID?, start: Date, end: Date, focusedSeconds: TimeInterval) {
        self.labelID = labelID
        self.start = start
        self.end = end
        self.focusedSeconds = focusedSeconds
    }
}

public enum GoalPeriod: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly

    public var bonusXP: Int {
        switch self {
        case .daily: XPRules.dailyGoalBonus
        case .weekly: XPRules.weeklyGoalBonus
        }
    }

    var component: Calendar.Component {
        switch self {
        case .daily: .day
        case .weekly: .weekOfYear
        }
    }

    public func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: component, for: date)!
    }

    func interval(before interval: DateInterval, calendar: Calendar) -> DateInterval {
        self.interval(containing: interval.start.addingTimeInterval(-1), calendar: calendar)
    }
}

/// A time target for one label.
public struct GoalSpec: Equatable, Sendable {
    public var id: UUID
    public var labelID: UUID
    public var period: GoalPeriod
    public var targetSeconds: TimeInterval

    public init(id: UUID, labelID: UUID, period: GoalPeriod, targetSeconds: TimeInterval) {
        self.id = id
        self.labelID = labelID
        self.period = period
        self.targetSeconds = targetSeconds
    }
}
