import Foundation

/// The colors a label can have. Tuned to a similar lightness so no label shouts over another,
/// and so each reads on light and dark glass.
public enum LabelPalette {
    public struct Swatch: Identifiable, Hashable, Sendable {
        public let name: String
        public let hex: String
        public var id: String { hex }
    }

    public static let all: [Swatch] = [
        Swatch(name: "Blue", hex: "#4C7BD9"),
        Swatch(name: "Indigo", hex: "#6E6AD8"),
        Swatch(name: "Violet", hex: "#9A6BD1"),
        Swatch(name: "Rose", hex: "#CF6A8B"),
        Swatch(name: "Coral", hex: "#D9785A"),
        Swatch(name: "Amber", hex: "#C4963A"),
        Swatch(name: "Olive", hex: "#879A4B"),
        Swatch(name: "Green", hex: "#4E9C77"),
        Swatch(name: "Teal", hex: "#3E95A6"),
        Swatch(name: "Slate", hex: "#7A8594"),
    ]

    /// The starter labels' v0.1 colors and the palette color that replaces each.
    public static let legacySeedColors: [String: String] = [
        "#0A5AD6": "#4C7BD9",
        "#8E3BD1": "#9A6BD1",
        "#C25E00": "#C4963A",
        "#1F8A3B": "#4E9C77",
    ]

    /// A color for a new label: the first one no label uses yet, or the least used.
    public static func suggestion(avoiding used: [String]) -> Swatch {
        let counts = Dictionary(used.map { ($0.uppercased(), 1) }, uniquingKeysWith: +)
        return all.min { counts[$0.hex, default: 0] < counts[$1.hex, default: 0] } ?? all[0]
    }
}
