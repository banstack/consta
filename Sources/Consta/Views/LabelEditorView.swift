import ConstaKit
import SwiftData
import SwiftUI

/// Create a label, or rename, recolor or archive one. Colors come from a fixed palette: the system
/// color panel is a separate window, and opening it dismisses the menu bar popover.
struct LabelEditorView: View {
    let labelID: UUID?
    @Binding var screen: Screen
    @Environment(\.modelContext) private var context
    @Query private var labels: [ActivityLabel]
    @State private var name = ""
    @State private var colorHex = LabelPalette.all[0].hex
    @State private var loaded = false
    @FocusState private var nameFocused: Bool

    private var label: ActivityLabel? {
        labels.first { $0.id == labelID }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// The palette, plus a label's current color if it was picked before the palette existed.
    private var swatches: [LabelPalette.Swatch] {
        let palette = LabelPalette.all
        guard let current = label?.colorHex.uppercased(), !palette.contains(where: { $0.hex == current }) else { return palette }
        return palette + [LabelPalette.Swatch(name: "Current", hex: current)]
    }

    var body: some View {
        VStack(spacing: 14) {
            ScreenHeader(title: labelID == nil ? "New label" : "Edit label", screen: $screen)

            GlassCard {
                HStack(spacing: 8) {
                    LabelDot(hex: colorHex, size: 10)
                    Text(trimmedName.isEmpty ? "Label" : trimmedName)
                        .foregroundStyle(trimmedName.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                }
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(.background, in: .rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .animation(.consta, value: colorHex)
            }

            VStack(spacing: 6) {
                SectionTitle("Name")
                TextField("Writing", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(save)
            }

            VStack(spacing: 6) {
                SectionTitle("Color")
                GlassCard(padding: 12) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(swatches) { swatch in
                            SwatchButton(swatch: swatch, isSelected: swatch.hex == colorHex) {
                                colorHex = swatch.hex
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if let label {
                    Button("Archive") {
                        label.isArchived = true
                        try? context.save()
                        screen = .settings
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .help("Hide this label. Its sessions stay in History.")
                }
                Button(labelID == nil ? "Create label" : "Done", action: save)
                    .buttonStyle(.ink)
                    .disabled(trimmedName.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let label {
                name = label.name
                colorHex = label.colorHex.uppercased()
            } else {
                colorHex = LabelPalette.suggestion(avoiding: labels.filter { !$0.isArchived }.map(\.colorHex)).hex
                nameFocused = true
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let label {
            label.name = trimmedName
            label.colorHex = colorHex
        } else {
            context.insert(ActivityLabel(name: trimmedName, colorHex: colorHex))
        }
        try? context.save()
        screen = .settings
    }
}

private struct SwatchButton: View {
    let swatch: LabelPalette.Swatch
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: swatch.hex))
                .frame(width: 26, height: 26)
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(Color(hex: swatch.hex), lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.7)
                }
                .scaleEffect(isSelected ? 1.06 : 1)
                .animation(.bouncy(duration: 0.25), value: isSelected)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(swatch.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(swatch.name)
    }
}
