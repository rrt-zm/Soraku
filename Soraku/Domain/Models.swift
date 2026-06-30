import Foundation
import CoreGraphics

enum GlyphMechanic: String, Codable, CaseIterable, Hashable {
    case none, crossing, twocolor, tilt, wetonwet, mirror

    var title: String {
        switch self {
        case .none: return "Pure Stroke"
        case .crossing: return "Crossing Bridges"
        case .twocolor: return "Two Inks"
        case .tilt: return "Hidden Tilt"
        case .wetonwet: return "Wet on Wet"
        case .mirror: return "Mirrored Forms"
        }
    }

    var lesson: String {
        switch self {
        case .none: return "Trace each line in one unbroken breath."
        case .crossing: return "Lines may cross over and under without meeting."
        case .twocolor: return "Vermilion and indigo lines join the black."
        case .tilt: return "Some lines wake only when you lean the device."
        case .wetonwet: return "Ink melts softly where strokes meet."
        case .mirror: return "Forms are reflected; complete the whole."
        }
    }
}

enum InkColorKind: String, Codable, Hashable {
    case black, vermilion, indigo

    var components: (r: Double, g: Double, b: Double) {
        switch self {
        case .black: return (0.055, 0.051, 0.043)
        case .vermilion: return (0.784, 0.266, 0.180)
        case .indigo: return (0.172, 0.243, 0.388)
        }
    }
}

struct GlyphNode: Codable, Hashable, Identifiable {
    let id: String
    let x: Double
    let y: Double
    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct GlyphSegment: Codable, Hashable, Identifiable {
    let id: String
    let a: String
    let b: String
    let color: InkColorKind
    let tiltRevealed: Bool
    let wet: Bool

    enum CodingKeys: String, CodingKey { case id, a, b, color, tiltRevealed, wet }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        a = try c.decode(String.self, forKey: .a)
        b = try c.decode(String.self, forKey: .b)
        color = (try? c.decode(InkColorKind.self, forKey: .color)) ?? .black
        tiltRevealed = (try? c.decode(Bool.self, forKey: .tiltRevealed)) ?? false
        wet = (try? c.decode(Bool.self, forKey: .wet)) ?? false
    }
}

struct CrossPoint: Codable, Hashable {
    let x: Double
    let y: Double
    var point: CGPoint { CGPoint(x: x, y: y) }
}

struct BreathProfile: Codable, Hashable {
    let tempo: Double
    let tolerance: Double
}

struct StarThresholds: Codable, Hashable {
    let calmBreathRatio: Double
    let maxBlots: Int
    let perfectStrokes: Int
}

struct LevelDefinition: Codable, Identifiable, Hashable {
    let id: String
    let chapterId: String
    let name: String
    let indexInChapter: Int
    let baseShape: String
    let nodes: [GlyphNode]
    let segments: [GlyphSegment]
    let crossings: [CrossPoint]
    let requiredStrokes: Int
    let breath: BreathProfile
    let mechanic: GlyphMechanic
    let starThresholds: StarThresholds
    let reward: Int
}

struct ChapterDefinition: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let palette: String
    let mechanic: GlyphMechanic
    let index: Int
    let unlockStars: Int
    let levelIds: [String]
    let introMechanic: GlyphMechanic
}

struct CosmeticDefinition: Codable, Identifiable, Hashable {
    let id: String
    let type: CosmeticKind
    let name: String
    let detail: String
    let cost: Int
    let isDefault: Bool
    let swatch: String?
    let tipWidth: Double?
    let tone: String?
    let accent: String?

    enum CodingKeys: String, CodingKey { case id, type, name, detail, cost, isDefault, swatch, tipWidth, tone, accent }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(CosmeticKind.self, forKey: .type)
        name = try c.decode(String.self, forKey: .name)
        detail = try c.decode(String.self, forKey: .detail)
        cost = try c.decode(Int.self, forKey: .cost)
        isDefault = (try? c.decode(Bool.self, forKey: .isDefault)) ?? false
        swatch = try? c.decode(String.self, forKey: .swatch)
        tipWidth = try? c.decode(Double.self, forKey: .tipWidth)
        tone = try? c.decode(String.self, forKey: .tone)
        accent = try? c.decode(String.self, forKey: .accent)
    }
}

enum CosmeticKind: String, Codable, CaseIterable, Hashable {
    case ink, brush, paper, theme, sound

    var title: String {
        switch self {
        case .ink: return "Inks"
        case .brush: return "Brushes"
        case .paper: return "Papers"
        case .theme: return "Scrolls"
        case .sound: return "Soundscapes"
        }
    }
}

struct QuestDefinition: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let metric: String
    let target: Int
    let reward: Int
}

struct AchievementDefinition: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let metric: String
    let target: Int
}
