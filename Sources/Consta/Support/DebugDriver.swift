#if DEBUG
import AppKit
import ConstaKit
import SwiftData
import SwiftUI

/// Debug-only remote control, used to exercise the app and take screenshots without Accessibility or
/// Screen Recording permission (everything here acts on Consta's own windows). The system's status item
/// can't be clicked from inside the process, so `open` shows the same popover and menu bar label, wired
/// to the app's tracker and store, in a window of our own under a strip of menu bar.
///
///     CONSTA_DRIVER=1 swift run Consta < commands
///
/// One command per line on stdin:
///     open                  show the popover window
///     click X Y             click in the window, in points from its top-left corner
///     type TEXT             type into the focused field
///     key return|escape|tab
///     shot PATH             write a PNG of the window (menu bar strip and popover)
///     sleep SECONDS         wait before the next command
///     dump                  print the saved sessions, goals, labels, XP and badges
///     sample                add a week of past sessions, for the History screen
///     frames                print the popover frame and focus state
///     quit
@MainActor
enum DebugDriver {
    static var isEnabled: Bool { ProcessInfo.processInfo.environment["CONSTA_DRIVER"] != nil }
    static var tracker: SessionTracker?
    static var container: ModelContainer?
    private static var popover: NSWindow?

    static func start() {
        Task.detached {
            for await line in Self.lines() {
                if line.hasPrefix("sleep "), let seconds = Double(line.dropFirst(6)) {
                    try? await Task.sleep(for: .seconds(seconds))
                    continue
                }
                await MainActor.run { handle(line) }
            }
            await MainActor.run { NSApp.terminate(nil) }
        }
    }

    nonisolated private static func lines() -> AsyncStream<String> {
        AsyncStream { continuation in
            Thread.detachNewThread {
                while let line = readLine() { continuation.yield(line) }
                continuation.finish()
            }
        }
    }

    private static func handle(_ line: String) {
        let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
        guard let command = parts.first else { return }
        let argument = parts.count > 1 ? parts[1] : ""
        switch command {
        case "open":
            openPopover()
        case "click":
            let numbers = argument.split(separator: " ").compactMap { Double($0) }
            guard numbers.count == 2 else { return report("click needs X Y") }
            click(at: CGPoint(x: numbers[0], y: numbers[1]))
        case "type":
            guard let window = popover else { return report("popover not open") }
            if let editor = window.firstResponder as? NSTextView {
                editor.insertText(argument, replacementRange: editor.selectedRange())
            } else {
                report("no focused text field")
            }
        case "key":
            let codes: [String: (UInt16, String)] = ["return": (36, "\r"), "escape": (53, "\u{1b}"), "tab": (48, "\t")]
            guard let (code, chars) = codes[argument] else { return report("unknown key") }
            key(code: code, characters: chars)
        case "shot":
            shot(to: argument)
        case "dump":
            dump()
        case "sample":
            addSampleSessions()
        case "frames":
            report("popover \(popover?.frame ?? .zero) key \(popover?.isKeyWindow ?? false) active \(NSApp.isActive)")
        case "quit":
            NSApp.terminate(nil)
        default:
            report("unknown command \(command)")
        }
    }

    /// Prints what's in the store, to check what the UI saved.
    private static func dump() {
        guard let context = container?.mainContext else { return }
        for session in (try? context.fetch(FetchDescriptor<FocusSession>())) ?? [] {
            report("session \(session.label?.name ?? "-") \(Int(session.focusedSeconds))s \(session.xp) XP note \"\(session.note)\"")
        }
        for goal in (try? context.fetch(FetchDescriptor<Goal>())) ?? [] {
            report("goal \(goal.label?.name ?? "-") \(goal.period) \(goal.targetMinutes)m")
        }
        let labels = ((try? context.fetch(FetchDescriptor<ActivityLabel>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []).map(\.name)
        report("labels \(labels)")
        report("xp \(ProgressStore.totalXP(context)) badges \(((try? context.fetch(FetchDescriptor<BadgeUnlock>())) ?? []).map(\.badgeID))")
    }

    /// A week of made-up sessions on the starter labels: (days ago, label index, start hour, minute, minutes, note).
    private static func addSampleSessions() {
        guard let context = container?.mainContext else { return }
        let labels = (try? context.fetch(FetchDescriptor<ActivityLabel>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        guard labels.count >= 4 else { return report("needs the four starter labels") }
        let plan: [(Int, Int, Int, Int, Double, String)] = [
            (0, 0, 9, 12, 85, "Wrote the history view spec and the swatch palette."),
            (0, 2, 12, 40, 35, "Two chapters of the SwiftData book."),
            (1, 1, 10, 0, 90, "Settings page in glass."),
            (1, 0, 13, 0, 80, ""),
            (1, 3, 18, 10, 15, "Short run."),
            (2, 0, 9, 30, 120, ""),
            (4, 1, 14, 0, 45, "Icon sketches."),
            (5, 0, 8, 45, 70, ""),
        ]
        let calendar = Calendar.current
        for (daysAgo, index, hour, minute, minutes, note) in plan {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: .now),
                  let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            let session = FocusSession(label: labels[index], start: start, end: start.addingTimeInterval(minutes * 60),
                                       focusedSeconds: minutes * 60, note: note, xp: XPRules.focusXP(seconds: minutes * 60))
            context.insert(session)
            context.insert(XPEvent(key: "session:\(session.id.uuidString)", amount: session.xp, reason: "Focus time", date: start))
        }
        try? context.save()
        report("added \(plan.count) sessions")
    }

    private static func report(_ message: String) {
        print("[driver] \(message)")
        fflush(stdout)
    }

    // MARK: - Window

    private static func openPopover() {
        guard let tracker, let container else { return report("not configured") }
        let host = NSHostingView(rootView: DriverFrame().environment(tracker).modelContainer(container))
        // Like the system's menu bar windows: takes key focus without activating the app.
        let window = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = host
        window.setContentSize(host.fittingSize)
        if let screen = NSScreen.main {
            window.setFrameTopLeftPoint(NSPoint(x: screen.visibleFrame.maxX - window.frame.width - 24, y: screen.visibleFrame.maxY))
        }
        // Resize with the content as screens change.
        host.sizingOptions = [.preferredContentSize]
        window.orderFrontRegardless()
        window.makeKey()
        popover = window
        report("opened \(window.frame)")
    }

    // MARK: - Input

    /// Controls track the mouse after mouse-down until a mouse-up arrives, so queue the up first.
    private static func sendClick(at location: NSPoint, in window: NSWindow) {
        func event(_ type: NSEvent.EventType) -> NSEvent? {
            NSEvent.mouseEvent(
                with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            )
        }
        guard let down = event(.leftMouseDown), let up = event(.leftMouseUp) else { return }
        NSApp.postEvent(up, atStart: false)
        window.sendEvent(down)
    }

    private static func click(at point: CGPoint) {
        guard let window = popover else { return report("popover not open") }
        // Other apps can take focus while we run; the real popover is key whenever it's open.
        window.makeKey()
        sendClick(at: NSPoint(x: point.x, y: window.frame.height - point.y), in: window)
        report("clicked \(Int(point.x)),\(Int(point.y))")
    }

    private static func key(code: UInt16, characters: String) {
        guard let window = popover else { return report("popover not open") }
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard let event = NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code
            ) else { continue }
            if type == .keyDown, window.performKeyEquivalent(with: event) { continue }
            window.sendEvent(event)
        }
    }

    // MARK: - Capture

    /// `CGWindowListCreateImage` is unavailable to Swift in the macOS 15+ SDK, but still works for an
    /// app's own windows without Screen Recording permission, so look it up at runtime.
    private typealias CreateImage = @convention(c) (CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption) -> Unmanaged<CGImage>?

    private static let createImage: CreateImage? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: CreateImage.self)
    }()

    private static func image(of window: NSWindow) -> CGImage? {
        guard let id = CGWindowID(exactly: window.windowNumber) else { return nil }
        return createImage?(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution])?.takeRetainedValue()
    }

    private static func shot(to path: String) {
        guard let window = popover else { return report("popover not open") }
        guard window.isKeyWindow else {
            window.makeKey()
            return report("popover was not key; refocused, take the shot again")
        }
        guard let composite = image(of: window) else { return report("could not capture") }
        guard let png = NSBitmapImageRep(cgImage: composite).representation(using: .png, properties: [:]) else {
            return report("could not encode")
        }
        do {
            try png.write(to: URL(filePath: path))
            report("wrote \(path)")
        } catch {
            report("write failed: \(error)")
        }
    }
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The popover under a strip of menu bar with the live menu bar label, on a wallpaper-like backdrop.
private struct DriverFrame: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 16) {
                Spacer()
                MenuBarLabel()
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(.white.opacity(0.2), in: .rect(cornerRadius: 5))
                Image(systemName: "wifi")
                Image(systemName: "battery.75percent")
                TimelineView(.everyMinute) { context in
                    Text(context.date, format: .dateTime.weekday().hour().minute())
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(.black.opacity(0.2))

            PopoverView()
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(width: 372)
        .background {
            LinearGradient(colors: [Color(hex: "#24345F"), Color(hex: "#5B4A8B"), Color(hex: "#C47A6A")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
#endif
