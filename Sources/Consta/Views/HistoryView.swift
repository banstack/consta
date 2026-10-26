import ConstaKit
import SwiftData
import SwiftUI

/// Past sessions, newest first and grouped by day, with the last seven days at a glance.
struct HistoryView: View {
    @Binding var screen: Screen
    @Environment(\.modelContext) private var context
    @Query(sort: \FocusSession.start, order: .reverse) private var sessions: [FocusSession]
    @State private var labelFilter: UUID?
    @State private var openID: UUID?

    private var shown: [FocusSession] {
        guard let labelFilter else { return sessions }
        return sessions.filter { $0.label?.id == labelFilter }
    }

    /// Labels that have sessions, archived ones included, so old history stays reachable.
    private var filterLabels: [ActivityLabel] {
        var seen = Set<UUID>()
        return sessions.compactMap(\.label)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        let days = Dictionary(grouping: shown) { Calendar.current.startOfDay(for: $0.start) }
            .sorted { $0.key > $1.key }

        VStack(spacing: 12) {
            ScreenHeader(title: "History", screen: $screen) { filterMenu }

            WeekStrip(totals: SessionHistory.dailyTotals(sessions: shown.map(\.record), now: .now))

            if days.isEmpty {
                Text(labelFilter == nil ? "No sessions yet. Finished sessions show up here." : "No sessions for this label yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
            }

            FittedScrollView(maxHeight: 340) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(days, id: \.key) { day in
                        HStack {
                            Text(Self.title(for: day.key))
                            Spacer()
                            Text(DurationFormat.short(day.value.reduce(0) { $0 + $1.focusedSeconds }))
                                .monospacedDigit()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                        ForEach(day.value) { session in
                            SessionRow(session: session, isOpen: openID == session.id) {
                                withAnimation(.consta) { openID = openID == session.id ? nil : session.id }
                            } onDelete: {
                                delete(session)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("All labels") { withAnimation(.consta) { labelFilter = nil } }
            Divider()
            ForEach(filterLabels) { label in
                Button(label.name) { withAnimation(.consta) { labelFilter = label.id } }
            }
        } label: {
            HStack(spacing: 6) {
                if let label = filterLabels.first(where: { $0.id == labelFilter }) {
                    LabelDot(hex: label.colorHex, size: 7)
                    Text(label.name)
                } else {
                    Text("All labels")
                }
            }
            .font(.caption)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .controlSize(.small)
        .fixedSize()
    }

    /// Removes the session and the focus XP it earned. Goal bonuses stay, since the goal was met at the time.
    private func delete(_ session: FocusSession) {
        let key = "session:\(session.id.uuidString)"
        if let event = try? context.fetch(FetchDescriptor<XPEvent>(predicate: #Predicate { $0.key == key })).first {
            context.delete(event)
        }
        withAnimation(.consta) { context.delete(session) }
        try? context.save()
    }

    static func title(for day: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

/// Focus time over the last seven days as small bars, today in full ink.
private struct WeekStrip: View {
    let totals: [DayTotal]

    var body: some View {
        let peak = max(totals.map(\.seconds).max() ?? 0, 1)
        let sum = totals.reduce(0) { $0 + $1.seconds }

        GlassCard {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last 7 days").font(.caption).foregroundStyle(.secondary)
                    Text(DurationFormat.short(sum))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(totals.enumerated()), id: \.offset) { index, total in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(index == totals.count - 1 ? AnyShapeStyle(.primary) : AnyShapeStyle(.primary.opacity(0.14)))
                                .frame(width: 10, height: max(3, 34 * total.seconds / peak))
                            Text(total.day.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Focus time per day")
                .accessibilityValue(totals.map { "\($0.day.formatted(.dateTime.weekday(.wide))) \(DurationFormat.short($0.seconds))" }.joined(separator: ", "))
            }
        }
    }
}

private struct SessionRow: View {
    let session: FocusSession
    let isOpen: Bool
    let toggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 10) {
                    LabelDot(hex: session.label?.colorHex ?? "#7A8594")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.label?.name ?? "Deleted label").font(.callout)
                        Text("\(session.start, format: .dateTime.hour().minute()) – \(session.end, format: .dateTime.hour().minute())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(DurationFormat.short(session.focusedSeconds))
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .frame(height: 40)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.note.isEmpty ? "No note" : session.note)
                        .font(.caption)
                        .foregroundStyle(session.note.isEmpty ? .tertiary : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("+\(session.xp) XP").monospacedDigit()
                        Spacer()
                        Button("Delete", role: .destructive, action: onDelete)
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.leading, 28)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(isOpen ? AnyShapeStyle(.background.opacity(0.7)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
        .clipShape(.rect(cornerRadius: 12))
        .contextMenu {
            Button("Delete session", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
    }
}
