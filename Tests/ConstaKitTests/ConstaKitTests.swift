import Foundation
import Testing
@testable import ConstaKit

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    return calendar
}()

/// 2026-10-26 is a Monday.
private func date(_ day: Int, _ hour: Int = 10, month: Int = 10) -> Date {
    utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private func session(_ label: UUID?, day: Int, hour: Int = 10, minutes: Double) -> SessionRecord {
    let start = date(day, hour)
    return SessionRecord(labelID: label, start: start, end: start.addingTimeInterval(minutes * 60), focusedSeconds: minutes * 60)
}

@Suite struct LevelingTests {
    @Test func curveMatchesMockups() {
        #expect(Leveling.xpToNextLevel(from: 1) == 300)
        #expect(Leveling.xpToNextLevel(from: 7) == 1800)
        #expect(Leveling.xpToNextLevel(from: 8) == 2050)
    }

    @Test func progressFromTotal() {
        #expect(Leveling.progress(totalXP: 0) == LevelProgress(level: 1, xpIntoLevel: 0, xpForNextLevel: 300))
        #expect(Leveling.progress(totalXP: 300).level == 2)
        let total = Leveling.totalXP(toReach: 7) + 1240
        #expect(Leveling.progress(totalXP: total) == LevelProgress(level: 7, xpIntoLevel: 1240, xpForNextLevel: 1800))
    }
}

@Suite struct GoalTests {
    let deep = UUID()

    @Test func dailyProgressAndStreak() {
        let goal = GoalSpec(id: UUID(), labelID: deep, period: .daily, targetSeconds: 3600)
        let sessions = [
            session(deep, day: 23, minutes: 60),
            session(deep, day: 24, minutes: 30), session(deep, day: 24, hour: 15, minutes: 30),
            session(deep, day: 25, minutes: 61),
            session(deep, day: 26, minutes: 20),
            session(UUID(), day: 26, minutes: 120),
        ]
        let status = GoalEvaluator.status(of: goal, sessions: sessions, now: date(26, 18), calendar: utc)
        #expect(status.focusedSeconds == 20 * 60)
        #expect(!status.isMet)
        #expect(status.streak == 3)
    }

    @Test func streakIncludesTodayOnceMet() {
        let goal = GoalSpec(id: UUID(), labelID: deep, period: .daily, targetSeconds: 1800)
        let sessions = [session(deep, day: 25, minutes: 30), session(deep, day: 26, minutes: 45)]
        let status = GoalEvaluator.status(of: goal, sessions: sessions, now: date(26, 18), calendar: utc)
        #expect(status.isMet)
        #expect(status.streak == 2)
    }

    @Test func weeklyGoalStartsMonday() {
        let goal = GoalSpec(id: UUID(), labelID: deep, period: .weekly, targetSeconds: 5 * 3600)
        let sessions = [session(deep, day: 25, minutes: 300), session(deep, day: 26, minutes: 60)]
        let status = GoalEvaluator.status(of: goal, sessions: sessions, now: date(27), calendar: utc)
        #expect(status.focusedSeconds == 3600)
        #expect(status.streak == 1)
    }

    @Test func dayStreakSurvivesUntilEndOfToday() {
        let sessions = [session(deep, day: 24, minutes: 5), session(deep, day: 25, minutes: 5)]
        #expect(DayStreak.current(sessions: sessions, now: date(26), calendar: utc) == 2)
        #expect(DayStreak.current(sessions: sessions, now: date(27), calendar: utc) == 0)
    }
}

@Suite struct ProgressionTests {
    let deep = UUID()

    @Test func paysFocusGoalBonusAndBadgesOnce() {
        let goal = GoalSpec(id: UUID(), labelID: deep, period: .daily, targetSeconds: 3600)
        let new = session(deep, day: 26, minutes: 70)
        let first = Progression.evaluate(
            newSession: new, pastSessions: [], goals: [goal],
            paidBonusKeys: [], unlockedBadgeIDs: [], currentXP: 250,
            now: date(26, 12), calendar: utc
        )
        #expect(first.focusXP == 70)
        #expect(first.goalBonuses.map(\.xp) == [50])
        #expect(first.totalXP == 120)
        #expect(first.newBadgeIDs == ["first-step"])
        #expect(first.leveledUp)

        let second = Progression.evaluate(
            newSession: session(deep, day: 26, hour: 14, minutes: 10), pastSessions: [new], goals: [goal],
            paidBonusKeys: Set(first.goalBonuses.map(\.key)), unlockedBadgeIDs: Set(first.newBadgeIDs),
            currentXP: 370, now: date(26, 15), calendar: utc
        )
        #expect(second.goalBonuses.isEmpty)
        #expect(second.newBadgeIDs.isEmpty)
        #expect(second.totalXP == 10)
    }
}

@Suite struct DurationFormatTests {
    @Test func formats() {
        #expect(DurationFormat.clock(2538) == "42:18")
        #expect(DurationFormat.clock(3723) == "1:02:03")
        #expect(DurationFormat.short(6000) == "1h 40m")
        #expect(DurationFormat.short(2100) == "35m")
        #expect(DurationFormat.short(10800) == "3h")
    }
}
