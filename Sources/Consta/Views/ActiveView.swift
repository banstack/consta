import ConstaKit
import SwiftData
import SwiftUI

/// A session is running: big timer, today's goal ring, pause and stop.
struct ActiveView: View {
    @Environment(SessionTracker.self) private var tracker
    @Query private var sessions: [FocusSession]
    @Query private var goals: [Goal]
    @Query private var xpEvents: [XPEvent]

    var body: some View {
        if let active = tracker.active {
            let color = Color(hex: active.colorHex)
            let elapsed = tracker.focusedSeconds
            let goal = goals.first { $0.label?.id == active.labelID && $0.period == .daily }?.spec
            let soFar = goal.map { GoalEvaluator.status(of: $0, sessions: sessions.map(\.record), now: tracker.now).focusedSeconds } ?? 0
            let ringFraction = goal.map { min(1, (soFar + elapsed) / $0.targetSeconds) } ?? (elapsed.truncatingRemainder(dividingBy: 3600) / 3600)
            let level = Leveling.progress(totalXP: xpEvents.reduce(0) { $0 + $1.amount } + XPRules.focusXP(seconds: elapsed))

            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        LabelDot(hex: active.colorHex)
                        Text(active.labelName)
                    }
                    .font(.callout.weight(.semibold))
                    Spacer()
                    Text("Started \(active.start, style: .time)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                ZStack {
                    Circle().stroke(.primary.opacity(0.06), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: ringFraction)
                        .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.smooth, value: ringFraction)
                    VStack(spacing: 4) {
                        Text(DurationFormat.clock(elapsed))
                            .font(.system(size: 40, weight: .light))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        if let goal {
                            Text("\(DurationFormat.short(soFar + elapsed)) of \(DurationFormat.short(goal.targetSeconds)) today")
                                .font(.caption).foregroundStyle(.secondary)
                        } else if active.isPaused {
                            Text("Paused").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 184, height: 184)

                HStack(spacing: 14) {
                    stat("+\(XPRules.focusXP(seconds: elapsed))", "XP")
                    if let goal {
                        stat(DurationFormat.short(max(0, goal.targetSeconds - soFar - elapsed)), "to goal")
                    }
                    stat("\(level.xpRemaining)", "XP to Lv \(level.level + 1)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                HStack(spacing: 8) {
                    Button {
                        tracker.togglePause()
                    } label: {
                        Label(active.isPaused ? "Resume" : "Pause", systemImage: active.isPaused ? "play.fill" : "pause.fill")
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                    Button {
                        tracker.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.ink)
                }
            }
        }
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        Text("\(Text(value).fontWeight(.semibold).foregroundStyle(.primary)) \(caption)")
    }
}
