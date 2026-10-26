import ConstaKit
import SwiftData
import SwiftUI

/// Level progress and the badge collection.
struct BadgesView: View {
    @Binding var screen: Screen
    @Query private var xpEvents: [XPEvent]
    @Query private var unlocks: [BadgeUnlock]

    var body: some View {
        let level = Leveling.progress(totalXP: xpEvents.reduce(0) { $0 + $1.amount })
        let earned = Set(unlocks.map(\.badgeID))

        VStack(spacing: 14) {
            ScreenHeader(title: "Progress", screen: $screen)

            VStack(spacing: 8) {
                LevelRing(progress: level, size: 76)
                Text("Level \(level.level)").font(.headline)
                ProgressLine(fraction: level.fraction, color: .accentColor, height: 6)
                Text("\(level.xpIntoLevel) / \(level.xpForNextLevel) XP to Level \(level.level + 1)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))

            HStack {
                Text("Badges").font(.headline)
                Spacer()
                Text("\(earned.count) of \(BadgeCatalog.all.count) earned").font(.caption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(BadgeCatalog.all) { badge in
                    BadgeTile(badge: badge, isEarned: earned.contains(badge.id))
                }
            }
        }
    }
}

private struct BadgeTile: View {
    let badge: Badge
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isEarned ? badge.symbol : "lock.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(isEarned ? .white : .secondary)
                .frame(width: 38, height: 38)
                .glassEffect(isEarned ? .regular.tint(Color(hex: badge.colorHex)) : .regular, in: .circle)
            Text(badge.name).font(.caption.weight(.semibold)).lineLimit(1)
            Text(badge.detail).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2)
        }
        .padding(.vertical, 10).padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .opacity(isEarned ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isEarned ? "Earned" : "Locked")
    }
}
