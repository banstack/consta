import AppKit
import SwiftData
import SwiftUI

@main
struct ConstaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var tracker = SessionTracker()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Schema(ConstaSchema.models))
        } catch {
            fatalError("Could not open the Consta store: \(error)")
        }
        ConstaSchema.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(tracker)
        } label: {
            MenuBarLabel()
                .environment(tracker)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon or app switcher entry.
        NSApp.setActivationPolicy(.accessory)
    }
}
