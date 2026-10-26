import ConstaKit
import SwiftData
import SwiftUI

/// Shown after Stop: what the session earned, an optional note, then save or discard.
struct CompleteView: View {
    let finished: FinishedSession
    @Environment(SessionTracker.self) private var tracker
    @Environment(\.modelContext) private var context
    @State private var note = ""
    @State private var outcome: SessionOutcome?

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.tint(Color(hex: finished.session.colorHex)), in: .circle)
                Text("Session complete").font(.title3.bold())
                Text("\(finished.session.labelName) · \(DurationFormat.short(finished.focusedSeconds)) · \(finished.session.start, style: .time)–\(finished.end, style: .time)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let outcome {
                if outcome.leveledUp {
                    Label("Level \(outcome.levelAfter.level) reached!", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: 14))
                }

                GlassCard {
                    row("Focus time", "+\(outcome.focusXP) XP")
                    ForEach(outcome.goalBonuses, id: \.key) { bonus in
                        row(bonus.period == .daily ? "Daily goal met" : "Weekly goal met", "+\(bonus.xp) XP")
                    }
                    Divider()
                    row("Total", "+\(outcome.totalXP) XP").fontWeight(.bold)
                }

                if !outcome.newBadgeIDs.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(outcome.newBadgeIDs.compactMap(BadgeCatalog.badge(id:))) { badge in
                            Label(badge.name, systemImage: badge.symbol)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .glassEffect(.regular.tint(Color(hex: badge.colorHex).opacity(0.4)), in: .capsule)
                        }
                    }
                    .accessibilityLabel("New badges")
                }
            }

            TextField("What did you get done? (optional)", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button("Discard", role: .destructive) {
                    tracker.finished = nil
                }
                .buttonStyle(.glass)

                Button {
                    if let outcome {
                        ProgressStore.save(finished, outcome: outcome, note: note, context: context)
                    }
                    tracker.finished = nil
                } label: {
                    Text("Save session").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .task(id: finished) {
            outcome = ProgressStore.preview(finished, context: context)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }
}
