import ConstaKit
import SwiftData
import SwiftUI

/// Pick a label and start. Kept deliberately small (see the v2 mockup).
struct IdleView: View {
    @Binding var screen: Screen
    @Environment(SessionTracker.self) private var tracker
    @Query(filter: #Predicate<ActivityLabel> { !$0.isArchived }, sort: \.createdAt) private var labels: [ActivityLabel]
    @Query private var xpEvents: [XPEvent]
    @Query private var sessions: [FocusSession]
    @Query private var goals: [Goal]
    @State private var selectedID: UUID?
    @Namespace private var selection

    /// Most recently used first; labels never used keep their creation order after those.
    private var recentLabels: [ActivityLabel] {
        labels.sorted { a, b in
            switch (a.lastUsedAt, b.lastUsedAt) {
            case let (x?, y?): x > y
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): a.createdAt < b.createdAt
            }
        }
    }

    private var selected: ActivityLabel? {
        recentLabels.first { $0.id == selectedID } ?? recentLabels.first
    }

    private var level: LevelProgress {
        Leveling.progress(totalXP: xpEvents.reduce(0) { $0 + $1.amount })
    }

    private var records: [SessionRecord] { sessions.map(\.record) }

    var body: some View {
        VStack(spacing: 14) {
            header
            labelGrid
            startButton
            if let selected { todayLine(for: selected) }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { screen = .badges } label: {
                HStack(spacing: 8) {
                    LevelRing(progress: level, size: 26)
                    Text("Level \(level.level)").font(.callout.weight(.semibold))
                    StreakBadge(days: DayStreak.current(sessions: records, now: .now))
                }
            }
            .buttonStyle(.plain)
            Spacer()
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    iconButton("clock", label: "History") { screen = .history }
                    iconButton("scope", label: "Goals") { screen = .goals }
                    iconButton("gearshape", label: "Settings") { screen = .settings }
                }
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(label)
            .help(label)
    }

    private var labelGrid: some View {
        let shown = Array(recentLabels.prefix(4))
        let more = Array(recentLabels.dropFirst(4))
        return VStack(spacing: 6) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(shown) { label in
                    LabelChip(label: label, isSelected: label.id == selected?.id, selection: selection) {
                        withAnimation(.consta) { selectedID = label.id }
                    }
                }
            }
            .padding(4)
            .background(.primary.opacity(0.04), in: .rect(cornerRadius: 16))
            if !more.isEmpty {
                Menu("More labels") {
                    ForEach(more) { label in
                        Button(label.name) { withAnimation(.consta) { selectedID = label.id } }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
    }

    private var startButton: some View {
        Button {
            if let selected { tracker.start(label: selected) }
        } label: {
            Label("Start \(selected?.name ?? "")", systemImage: "play.fill")
                .contentTransition(.interpolate)
        }
        .buttonStyle(.ink)
        .disabled(selected == nil)
        .keyboardShortcut(.defaultAction)
    }

    @ViewBuilder
    private func todayLine(for label: ActivityLabel) -> some View {
        let today = GoalPeriod.daily.interval(containing: .now, calendar: .current)
        let totalToday = records.filter { today.contains($0.start) }.reduce(0) { $0 + $1.focusedSeconds }
        let goal = goals.first { $0.label?.id == label.id && $0.period == .daily }?.spec
        let status = goal.map { GoalEvaluator.status(of: $0, sessions: records, now: .now) }

        VStack(spacing: 5) {
            if let status {
                ProgressLine(fraction: status.fraction, color: Color(hex: label.colorHex), height: 4)
            }
            HStack {
                if let status {
                    Text(status.isMet
                         ? "Goal met · \(DurationFormat.short(status.focusedSeconds)) of \(DurationFormat.short(status.goal.targetSeconds))"
                         : "\(DurationFormat.short(status.focusedSeconds)) of \(DurationFormat.short(status.goal.targetSeconds)) goal")
                } else {
                    Text("No daily goal for \(label.name)")
                }
                Spacer()
                Text("\(DurationFormat.short(totalToday)) today")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}

/// One label in the picker. The selected one sits on a raised pane that slides between chips.
struct LabelChip: View {
    let label: ActivityLabel
    let isSelected: Bool
    let selection: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                LabelDot(hex: label.colorHex)
                    .opacity(isSelected ? 1 : 0.75)
                Text(label.name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .contentShape(.rect)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                        .matchedGeometryEffect(id: "selected", in: selection)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
