import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

struct Palette: Equatable {
    var paper: Color
    var paperEdge: Color
    var paperGrain: Color
    var ink: Color
    var inkSoft: Color
    var ghost: Color
    var accent: Color
    var indigo: Color
    var vermilion: Color
    var background: [Color]
    var panel: Color
    var panelEdge: Color
    var textPrimary: Color
    var textSecondary: Color
    var star: Color
    var error: Color
    var breath: Color
    var isDark: Bool

    static func resolve(theme: AppTheme, systemDark: Bool, paperTone: String, inkSwatch: String, accentHex: String) -> Palette {
        let dark: Bool
        switch theme {
        case .day: dark = false
        case .night: dark = true
        case .system: dark = systemDark
        }
        let accent = Color(hex: accentHex)
        if dark {
            return Palette(
                paper: Color(hex: "1A1814"),
                paperEdge: Color(hex: "12100D"),
                paperGrain: Color.white.opacity(0.03),
                ink: Color(hex: "EDE6D6"),
                inkSoft: Color(hex: "EDE6D6").opacity(0.55),
                ghost: Color(hex: "EDE6D6").opacity(0.14),
                accent: accent,
                indigo: Color(hex: "6E84B8"),
                vermilion: Color(hex: "D6604A"),
                background: [Color(hex: "16140F"), Color(hex: "0C0B08")],
                panel: Color(hex: "201D17"),
                panelEdge: Color(hex: "332C22"),
                textPrimary: Color(hex: "ECE3D2"),
                textSecondary: Color(hex: "ECE3D2").opacity(0.6),
                star: Color(hex: "D9B45A"),
                error: Color(hex: "C8553E"),
                breath: accent,
                isDark: true
            )
        }
        return Palette(
            paper: Color(hex: paperTone),
            paperEdge: Color(hex: paperTone).opacity(0.0),
            paperGrain: Color(hex: "5A4B33").opacity(0.05),
            ink: Color(hex: inkSwatch),
            inkSoft: Color(hex: inkSwatch).opacity(0.5),
            ghost: Color(hex: "3A2F1F").opacity(0.16),
            accent: accent,
            indigo: Color(hex: "2C3E63"),
            vermilion: Color(hex: "C8442E"),
            background: [Color(hex: "EDE2CC"), Color(hex: "DFD0B2")],
            panel: Color(hex: "E7D9BE"),
            panelEdge: Color(hex: "C9B68F"),
            textPrimary: Color(hex: "2A2016"),
            textSecondary: Color(hex: "2A2016").opacity(0.6),
            star: Color(hex: "B8862F"),
            error: Color(hex: "B23A22"),
            breath: accent,
            isDark: false
        )
    }

    func ink(for kind: InkColorKind) -> Color {
        switch kind {
        case .black: return ink
        case .vermilion: return vermilion
        case .indigo: return indigo
        }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.resolve(theme: .day, systemDark: false, paperTone: "F2E9D8", inkSwatch: "0E0D0B", accentHex: "C8442E")
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
