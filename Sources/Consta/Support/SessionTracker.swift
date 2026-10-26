import ConstaKit
import Foundation
import Observation

/// The session currently running. Persisted so a quit or crash doesn't lose it.
struct ActiveSession: Codable, Equatable {
    var labelID: UUID
    var labelName: String
    var colorHex: String
    var start: Date
    var pausedAt: Date?
    var pausedSeconds: TimeInterval = 0

    var isPaused: Bool { pausedAt != nil }

    func focusedSeconds(at now: Date) -> TimeInterval {
        let pausedNow = pausedAt.map { now.timeIntervalSince($0) } ?? 0
        return max(0, now.timeIntervalSince(start) - pausedSeconds - pausedNow)
    }
}

/// A stopped session waiting for the user to save or discard it.
struct FinishedSession: Equatable {
    var session: ActiveSession
    var end: Date
    var focusedSeconds: TimeInterval

    var record: SessionRecord {
        SessionRecord(labelID: session.labelID, start: session.start, end: end, focusedSeconds: focusedSeconds)
    }
}

/// Owns the stopwatch and drives the live menu bar timer.
@MainActor
@Observable
final class SessionTracker {
    private(set) var active: ActiveSession? {
        didSet { persist() }
    }
    var finished: FinishedSession?
    /// Ticks once a second while a session runs, so views showing elapsed time refresh.
    private(set) var now = Date.now

    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "activeSession"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(ActiveSession.self, from: data) {
            active = saved
            startTicking()
        }
    }

    var focusedSeconds: TimeInterval {
        active?.focusedSeconds(at: now) ?? 0
    }

    func start(label: ActivityLabel) {
        label.lastUsedAt = .now
        now = .now
        active = ActiveSession(labelID: label.id, labelName: label.name, colorHex: label.colorHex, start: now)
        startTicking()
    }

    func togglePause() {
        guard var session = active else { return }
        now = .now
        if let pausedAt = session.pausedAt {
            session.pausedSeconds += now.timeIntervalSince(pausedAt)
            session.pausedAt = nil
        } else {
            session.pausedAt = now
        }
        active = session
    }

    func stop() {
        guard let session = active else { return }
        now = .now
        finished = FinishedSession(session: session, end: now, focusedSeconds: session.focusedSeconds(at: now))
        active = nil
        ticker?.cancel()
        ticker = nil
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.now = .now
            }
        }
    }

    private func persist() {
        if let active, let data = try? JSONEncoder().encode(active) {
            defaults.set(data, forKey: Self.storageKey)
        } else {
            defaults.removeObject(forKey: Self.storageKey)
        }
    }
}
