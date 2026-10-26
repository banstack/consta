import SwiftUI

enum Screen: Hashable {
    case home, goals, badges, history, settings
    /// Editing a label, or creating one when nil.
    case label(UUID?)

    /// How deep the screen sits, so moving deeper slides in from the right and going back from the left.
    var depth: Int {
        switch self {
        case .home: 0
        case .label: 2
        default: 1
        }
    }

    /// Where Back goes.
    var parent: Screen {
        if case .label = self { .settings } else { .home }
    }
}

/// Root of the menu bar window. Picks the screen from the session state first,
/// then from where the user navigated.
struct PopoverView: View {
    @Environment(SessionTracker.self) private var tracker
    @State private var screen: Screen = .home
    @State private var forward = true

    /// Every screen change goes through here so it animates in the right direction.
    private var navigation: Binding<Screen> {
        Binding {
            screen
        } set: { next in
            forward = next.depth >= screen.depth
            withAnimation(.consta) { screen = next }
        }
    }

    var body: some View {
        ZStack {
            if let finished = tracker.finished {
                CompleteView(finished: finished)
                    .transition(.blurReplace)
            } else if tracker.active != nil {
                ActiveView()
                    .transition(.blurReplace)
            } else {
                Group {
                    switch screen {
                    case .home: IdleView(screen: navigation)
                    case .goals: GoalsView(screen: navigation)
                    case .badges: BadgesView(screen: navigation)
                    case .history: HistoryView(screen: navigation)
                    case .settings: SettingsView(screen: navigation)
                    case .label(let id): LabelEditorView(labelID: id, screen: navigation)
                    }
                }
                .id(screen)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .padding(14)
        .frame(width: 300)
        .clipped()
        .animation(.consta, value: tracker.active?.labelID)
        .animation(.consta, value: tracker.finished)
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
                screen = screen.parent
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Back")

            Text(title).font(.headline)
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
