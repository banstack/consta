import AppKit
import SwiftData
import SwiftUI

/// Manage labels and quit.
struct SettingsView: View {
    @Binding var screen: Screen
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<ActivityLabel> { !$0.isArchived }, sort: \.createdAt) private var labels: [ActivityLabel]
    @State private var newName = ""
    @State private var newColor = Color(hex: "#0A5AD6")

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: "Labels", screen: $screen)

            FittedScrollView(maxHeight: 280) {
                VStack(spacing: 6) {
                    ForEach(labels) { label in
                        LabelRow(label: label)
                    }
                }
            }

            GlassCard {
                HStack {
                    ColorPicker("Color", selection: $newColor, supportsOpacity: false).labelsHidden()
                    TextField("New label", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .buttonStyle(.glassProminent)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Button("Quit Consta") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.glass)
                .keyboardShortcut("q")
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        context.insert(ActivityLabel(name: name, colorHex: newColor.hexString))
        newName = ""
    }
}

private struct LabelRow: View {
    @Bindable var label: ActivityLabel

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker("Color", selection: Binding(
                get: { Color(hex: label.colorHex) },
                set: { label.colorHex = $0.hexString }
            ), supportsOpacity: false)
            .labelsHidden()
            TextField("Name", text: $label.name)
                .textFieldStyle(.plain)
            Button("Archive", systemImage: "archivebox") { label.isArchived = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Archive label (keeps its history)")
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}
