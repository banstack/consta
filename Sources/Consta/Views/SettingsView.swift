import AppKit
import ServiceManagement
import SwiftData
import SwiftUI

/// Labels, a couple of preferences, and which build this is.
struct SettingsView: View {
    @Binding var screen: Screen
    @Query(filter: #Predicate<ActivityLabel> { !$0.isArchived }, sort: \.createdAt) private var labels: [ActivityLabel]
    @AppStorage(MenuBarLabel.showTimerKey) private var showTimer = true
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            ScreenHeader(title: "Settings", screen: $screen)

            VStack(spacing: 4) {
                SectionTitle("Labels")
                GlassCard(padding: 4) {
                    FittedScrollView(maxHeight: 180) {
                        VStack(spacing: 0) {
                            ForEach(labels) { label in
                                row { screen = .label(label.id) } content: {
                                    LabelDot(hex: label.colorHex)
                                    Text(label.name)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    row { screen = .label(nil) } content: {
                        Image(systemName: "plus").font(.caption.weight(.bold))
                        Text("New label").fontWeight(.medium)
                        Spacer()
                    }
                }
            }

            VStack(spacing: 4) {
                SectionTitle("General")
                GlassCard(padding: 4) {
                    Toggle("Show timer in menu bar", isOn: $showTimer)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                    Toggle("Open at login", isOn: Binding(get: { opensAtLogin }, set: setOpensAtLogin))
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .disabled(!AppVersion.isBundled)
                        .help(AppVersion.isBundled ? "" : "Only available in the installed app")
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(.primary)
                .font(.callout)
            }

            VStack(spacing: 4) {
                SectionTitle("About")
                GlassCard(padding: 10) {
                    HStack(spacing: 10) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 36, height: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Consta").font(.callout.weight(.semibold))
                            Text(AppVersion.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button(copied ? "Copied" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("Consta \(AppVersion.description)", forType: .string)
                            withAnimation(.consta) { copied = true }
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .contentTransition(.interpolate)
                        .help("Copy the version, for bug reports")
                    }
                }
            }

            HStack {
                Link("Release notes", destination: URL(string: "https://github.com/banstack/consta/releases")!)
                Spacer()
                Button("Quit Consta") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .keyboardShortcut("q")
            }
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 4)
        }
    }

    private func row<Content: View>(action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            HStack(spacing: 10) { content() }
                .font(.callout)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func setOpensAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSSound.beep()
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// The marketing version and build number that scripts/build-app.sh writes into Info.plist.
enum AppVersion {
    static var isBundled: Bool { Bundle.main.bundleIdentifier != nil }

    static var description: String {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let version = info["CFBundleShortVersionString"] as? String else { return "Development build" }
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (build \(build))"
    }
}
