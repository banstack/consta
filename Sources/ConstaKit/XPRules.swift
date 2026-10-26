import Foundation

public enum XPRules {
    public static let xpPerFocusedMinute = 1
    public static let dailyGoalBonus = 50
    public static let weeklyGoalBonus = 200

    public static func focusXP(seconds: TimeInterval) -> Int {
        Int(seconds / 60) * xpPerFocusedMinute
    }
}
