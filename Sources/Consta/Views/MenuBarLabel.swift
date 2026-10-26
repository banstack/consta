import ConstaKit
import SwiftUI

/// The menu bar item: the Consta glyph when idle, the live timer while a session runs.
struct MenuBarLabel: View {
    static let showTimerKey = "showMenuBarTimer"
    @Environment(SessionTracker.self) private var tracker
    @AppStorage(showTimerKey) private var showTimer = true

    var body: some View {
        if let active = tracker.active {
            HStack(spacing: 4) {
                Image(systemName: active.isPaused ? "pause.circle.fill" : "circle.fill")
                    .foregroundStyle(Color(hex: active.colorHex))
                if showTimer {
                    Text(DurationFormat.clock(tracker.focusedSeconds))
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Consta, \(active.labelName) \(DurationFormat.short(tracker.focusedSeconds))")
        } else {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .accessibilityLabel("Consta")
        }
    }
}
