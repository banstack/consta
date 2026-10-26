import ConstaKit
import Foundation
import SwiftData

/// A label/tag a session is filed under, like "Deep Work".
@Model
final class ActivityLabel {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var lastUsedAt: Date?
    var isArchived: Bool

    @Relationship(deleteRule: .nullify, inverse: \FocusSession.label)
    var sessions: [FocusSession] = []

    @Relationship(deleteRule: .cascade, inverse: \Goal.label)
    var goals: [Goal] = []

    init(name: String, colorHex: String) {
        id = UUID()
        self.name = name
        self.colorHex = colorHex
        createdAt = .now
        isArchived = false
    }
}

@Model
final class FocusSession {
    @Attribute(.unique) var id: UUID
    var label: ActivityLabel?
    var start: Date
    var end: Date
    var focusedSeconds: Double
    var note: String
    var xp: Int

    init(label: ActivityLabel?, start: Date, end: Date, focusedSeconds: Double, note: String, xp: Int) {
        id = UUID()
        self.label = label
        self.start = start
        self.end = end
        self.focusedSeconds = focusedSeconds
        self.note = note
        self.xp = xp
    }

    var record: SessionRecord {
        SessionRecord(labelID: label?.id, start: start, end: end, focusedSeconds: focusedSeconds)
    }
}

/// A time target for one label, per day or per week.
@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var label: ActivityLabel?
    var periodRaw: String
    var targetMinutes: Int

    init(label: ActivityLabel, period: GoalPeriod, targetMinutes: Int) {
        id = UUID()
        self.label = label
        periodRaw = period.rawValue
        self.targetMinutes = targetMinutes
    }

    var period: GoalPeriod {
        get { GoalPeriod(rawValue: periodRaw) ?? .daily }
        set { periodRaw = newValue.rawValue }
    }

    var spec: GoalSpec? {
        guard let label else { return nil }
        return GoalSpec(id: id, labelID: label.id, period: period, targetSeconds: Double(targetMinutes) * 60)
    }
}

/// One XP award. Total XP is the sum of these; `key` makes each award happen once.
@Model
final class XPEvent {
    @Attribute(.unique) var key: String
    var amount: Int
    var reason: String
    var date: Date

    init(key: String, amount: Int, reason: String, date: Date = .now) {
        self.key = key
        self.amount = amount
        self.reason = reason
        self.date = date
    }
}

@Model
final class BadgeUnlock {
    @Attribute(.unique) var badgeID: String
    var date: Date

    init(badgeID: String, date: Date = .now) {
        self.badgeID = badgeID
        self.date = date
    }
}

enum ConstaSchema {
    static let models: [any PersistentModel.Type] = [
        ActivityLabel.self, FocusSession.self, Goal.self, XPEvent.self, BadgeUnlock.self,
    ]

    /// Starter labels so the popover isn't empty on first launch.
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ActivityLabel>())) ?? 0
        guard count == 0 else { return }
        for (name, hex) in [("Deep Work", "#0A5AD6"), ("Design", "#8E3BD1"), ("Reading", "#C25E00"), ("Exercise", "#1F8A3B")] {
            context.insert(ActivityLabel(name: name, colorHex: hex))
        }
        try? context.save()
    }
}
