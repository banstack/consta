import AppKit
import SwiftData
import SwiftUI

@main
struct ConstaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var tracker: SessionTracker
    private let container: ModelContainer

    init() {
        var inMemory = false
        var defaults = UserDefaults.standard
        #if DEBUG
        // Keep scripted runs away from the real store and the persisted active session.
        if DebugDriver.isEnabled, let scratch = UserDefaults(suiteName: "consta.driver") {
            scratch.removePersistentDomain(forName: "consta.driver")
            inMemory = true
            defaults = scratch
        }
        #endif
        let tracker = SessionTracker(defaults: defaults)
        _tracker = State(initialValue: tracker)
        do {
            container = try ModelContainer(for: Schema(ConstaSchema.models), configurations: ConstaSchema.configuration(inMemory: inMemory))
        } catch {
            fatalError("Could not open the Consta store: \(error)")
        }
        ConstaSchema.seedIfNeeded(container.mainContext)
        #if DEBUG
        DebugDriver.tracker = tracker
        DebugDriver.container = container
        #endif
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
        #if DEBUG
        if DebugDriver.isEnabled { DebugDriver.start() }
        #endif
    }
}
