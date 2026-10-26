import SwiftUI

/// The v2 look: neutral ink and glass, with a label's color used only to say which label it is
/// (its dot, the timer ring, progress lines). See "v2" in the Consta Screens gallery.
extension Color {
    /// Streaks are the one other use of color.
    static let streak = Color(hex: "#B07A10")
}

extension Animation {
    /// Moving between screens, and the selection sliding between labels.
    static let consta = Animation.smooth(duration: 0.3)
}

/// The primary action on a screen: an ink capsule that inverts in dark mode.
struct InkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.background)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(.primary, in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
}

/// A label's color, as a small dot.
struct LabelDot: View {
    let hex: String
    var size: CGFloat = 8

    var body: some View {
        Circle().fill(Color(hex: hex)).frame(width: size, height: size)
    }
}

/// Small grey heading over a group, like "Labels" in Settings.
struct SectionTitle: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
