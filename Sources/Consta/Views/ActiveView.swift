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
                    Label(active.labelName, systemImage: "circle.fill")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .glassEffect(.regular.tint(color), in: .capsule)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Started \(active.start, style: .time)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: ringFraction)
                        .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.smooth, value: ringFraction)
                    VStack(spacing: 4) {
                        Text(DurationFormat.clock(elapsed))
                            .font(.system(size: 44, weight: .light))
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
                .frame(width: 200, height: 200)

                HStack(spacing: 8) {
                    stat("+\(XPRules.focusXP(seconds: elapsed))", "XP so far")
                    if let goal {
                        stat(DurationFormat.short(max(0, goal.targetSeconds - soFar - elapsed)), "to daily goal")
                    }
                    stat("\(level.xpRemaining)", "XP to Lv \(level.level + 1)")
                }

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            tracker.togglePause()
                        } label: {
                            Label(active.isPaused ? "Resume" : "Pause", systemImage: active.isPaused ? "play.fill" : "pause.fill")
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                        .buttonStyle(.glass)

                        Button {
                            tracker.stop()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.red)
                    }
                    .controlSize(.large)
                    .font(.headline)
                }
            }
        }
    }

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}
