import ConstaKit
import SwiftUI

/// The menu bar item: the Consta glyph when idle, the live timer while a session runs.
struct MenuBarLabel: View {
    @Environment(SessionTracker.self) private var tracker

    var body: some View {
        if let active = tracker.active {
            HStack(spacing: 4) {
                Image(systemName: active.isPaused ? "pause.circle.fill" : "circle.fill")
                    .foregroundStyle(Color(hex: active.colorHex))
                Text(DurationFormat.clock(tracker.focusedSeconds))
                    .monospacedDigit()
            }
        } else {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .accessibilityLabel("Consta")
        }
    }
}
