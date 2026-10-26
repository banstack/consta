import ConstaKit
import SwiftData
import SwiftUI

/// Time targets per label, for today or this week.
struct GoalsView: View {
    @Binding var screen: Screen
    @Environment(\.modelContext) private var context
    @Query private var goals: [Goal]
    @Query private var sessions: [FocusSession]
    @State private var period: GoalPeriod = .daily
    @State private var isAdding = false

    var body: some View {
        let records = sessions.map(\.record)
        let shown = goals
            .filter { $0.period == period && $0.label != nil }
            .sorted { ($0.label?.name ?? "") < ($1.label?.name ?? "") }

        VStack(spacing: 14) {
            ScreenHeader(title: "Goals", screen: $screen) {
                Button("New goal", systemImage: "plus") { withAnimation(.consta) { isAdding.toggle() } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }

            Picker("Period", selection: $period) {
                Text("Today").tag(GoalPeriod.daily)
                Text("This week").tag(GoalPeriod.weekly)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if isAdding {
                NewGoalForm(period: period) { withAnimation(.consta) { isAdding = false } }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if shown.isEmpty && !isAdding {
                Text("No \(period == .daily ? "daily" : "weekly") goals yet. Add one to earn +\(period.bonusXP) XP each time you hit it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
            }

            FittedScrollView(maxHeight: 360) {
                VStack(spacing: 8) {
                    ForEach(shown) { goal in
                        if let spec = goal.spec, let label = goal.label {
                            GoalRow(label: label, status: GoalEvaluator.status(of: spec, sessions: records, now: .now))
                                .contextMenu {
                                    Button("Delete goal", role: .destructive) { context.delete(goal) }
                                }
                        }
                    }
                }
            }
        }
    }
}

private struct GoalRow: View {
    let label: ActivityLabel
    let status: GoalStatus

    var body: some View {
        let color = Color(hex: label.colorHex)
        let unit = status.goal.period == .daily ? "day" : "week"
        GlassCard {
            HStack(spacing: 8) {
                LabelDot(hex: label.colorHex)
                Text(label.name).font(.callout.weight(.semibold))
                Spacer()
                if status.isMet {
                    Label("Done", systemImage: "checkmark").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                Label("\(status.streak) \(unit)\(status.streak == 1 ? "" : "s")", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.streak)
            }
            ProgressLine(fraction: status.fraction, color: color, height: 4)
            HStack {
                Text("\(DurationFormat.short(status.focusedSeconds)) of \(DurationFormat.short(status.goal.targetSeconds))")
                Spacer()
                Text(status.isMet ? "+\(status.goal.period.bonusXP) XP earned" : "+\(status.goal.period.bonusXP) XP on finish")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}

private struct NewGoalForm: View {
    let period: GoalPeriod
    let onDone: () -> Void
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ActivityLabel> { !$0.isArchived }, sort: \.name) private var labels: [ActivityLabel]
    @State private var labelID: UUID?
    @State private var minutes = 60

    var body: some View {
        GlassCard {
            Picker("Label", selection: $labelID) {
                ForEach(labels) { label in
                    Text(label.name).tag(Optional(label.id))
                }
            }
            Stepper(value: $minutes, in: 15...(period == .daily ? 960 : 4800), step: 15) {
                Text("Target: \(DurationFormat.short(Double(minutes) * 60)) per \(period == .daily ? "day" : "week")")
                    .monospacedDigit()
            }
            HStack {
                Button("Cancel", action: onDone).buttonStyle(.glass)
                Spacer()
                Button("Add goal") {
                    if let label = labels.first(where: { $0.id == labelID }) {
                        context.insert(Goal(label: label, period: period, targetMinutes: minutes))
                    }
                    onDone()
                }
                .buttonStyle(.ink)
                .frame(width: 110)
                .disabled(labelID == nil)
            }
        }
        .onAppear { labelID = labelID ?? labels.first?.id }
    }
}
