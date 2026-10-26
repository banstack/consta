import SwiftUI

enum Screen {
    case home, goals, badges, settings
}

/// Root of the menu bar window. Picks the screen from the session state first,
/// then from where the user navigated.
struct PopoverView: View {
    @Environment(SessionTracker.self) private var tracker
    @State private var screen: Screen = .home

    var body: some View {
        Group {
            if let finished = tracker.finished {
                CompleteView(finished: finished)
            } else if tracker.active != nil {
                ActiveView()
            } else {
                switch screen {
                case .home: IdleView(screen: $screen)
                case .goals: GoalsView(screen: $screen)
                case .badges: BadgesView(screen: $screen)
                case .settings: SettingsView(screen: $screen)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .animation(.smooth(duration: 0.25), value: screen)
        .animation(.smooth(duration: 0.25), value: tracker.active?.labelID)
        .animation(.smooth(duration: 0.25), value: tracker.finished)
    }
}

/// Back button + title, shared by the secondary screens.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @Binding var screen: Screen
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Button {
                screen = .home
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Back")

            Text(title).font(.title3.bold())
            Spacer()
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, screen: Binding<Screen>) {
        self.init(title: title, screen: screen) { EmptyView() }
    }
}
