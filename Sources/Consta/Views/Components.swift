import ConstaKit
import SwiftUI

/// Small circular level badge with progress around it.
struct LevelRing: View {
    let progress: LevelProgress
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: size / 9)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: size / 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(progress.level)")
                .font(.system(size: size * 0.4, weight: .bold))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Level \(progress.level), \(Int(progress.fraction * 100)) percent to the next level")
    }
}

struct StreakBadge: View {
    let days: Int

    var body: some View {
        Label("\(days)", systemImage: "flame.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .labelStyle(.titleAndIcon)
            .accessibilityLabel("\(days)-day streak")
    }
}

struct ProgressLine: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color).frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
    }
}

/// A rounded glass panel for grouping content inside the popover.
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}
