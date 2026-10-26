import Foundation

/// Where a player stands on the level curve.
public struct LevelProgress: Equatable, Sendable {
    public let level: Int
    /// XP earned since reaching `level`.
    public let xpIntoLevel: Int
    /// XP needed to go from `level` to `level + 1`.
    public let xpForNextLevel: Int

    public var xpRemaining: Int { xpForNextLevel - xpIntoLevel }
    public var fraction: Double { Double(xpIntoLevel) / Double(xpForNextLevel) }
}

public enum Leveling {
    /// XP needed to go from `level` to `level + 1`.
    /// Level 1 → 2 takes 300 XP and each level after takes 250 more than the last,
    /// so an hour of focus a day levels you up roughly every few days early on
    /// and every couple of weeks later.
    public static func xpToNextLevel(from level: Int) -> Int {
        250 * level + 50
    }

    /// Total XP needed to reach `level` from zero.
    public static func totalXP(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (1..<level).reduce(0) { $0 + xpToNextLevel(from: $1) }
    }

    public static func progress(totalXP: Int) -> LevelProgress {
        var level = 1
        var remaining = max(0, totalXP)
        while remaining >= xpToNextLevel(from: level) {
            remaining -= xpToNextLevel(from: level)
            level += 1
        }
        return LevelProgress(level: level, xpIntoLevel: remaining, xpForNextLevel: xpToNextLevel(from: level))
    }
}
