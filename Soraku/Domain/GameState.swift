import Foundation

enum AppTheme: String, Codable, CaseIterable, Hashable {
    case day, night, system
    var title: String {
        switch self {
        case .day: return "Day"
        case .night: return "Dusk"
        case .system: return "System"
        }
    }
}

struct GameSettings: Codable, Hashable {
    var soundEnabled: Bool = true
    var musicEnabled: Bool = true
    var ambienceEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var reducedMotion: Bool = false
    var brushTiltSensitivity: Double = 0.5
    var theme: AppTheme = .system
}

struct InProgressLevel: Codable, Hashable {
    var levelId: String
    var inkedSegments: [String]
    var strokeRecords: [SavedStrokeRecord]
}

struct SavedStrokeRecord: Codable, Hashable {
    var segmentIds: [String]
    var duration: Double
    var inkLength: Double
    var blotted: Bool
    var calm: Bool
    var perfect: Bool

    var record: StrokeRecord {
        StrokeRecord(segmentIds: segmentIds, duration: duration, inkLength: inkLength, blotted: blotted, calm: calm, perfect: perfect)
    }

    init(_ r: StrokeRecord) {
        segmentIds = r.segmentIds
        duration = r.duration
        inkLength = r.inkLength
        blotted = r.blotted
        calm = r.calm
        perfect = r.perfect
    }
}

enum Metric: String, CaseIterable {
    case glyphsTraced
    case calmBreaths
    case blotFreeGlyphs
    case starsEarned
    case chaptersCleared
    case perfectStrokes
    case dailyCompleted
    case zenSeconds
    case crossingGlyphs
    case reachedFinalChapter
    case cosmeticsUnlocked
    case timePlayedSeconds
    case totalStrokes
}

struct GameSnapshot: Codable, Hashable {
    var schemaVersion: Int = 2
    var levelStars: [String: Int] = [:]
    var inProgress: InProgressLevel?
    var currency: Int = 0
    var unlockedCosmetics: [String] = []
    var equipped: [String: String] = [:]
    var claimedQuests: [String] = []
    var metrics: [String: Int] = [:]
    var settings: GameSettings = GameSettings()
    var onboardingComplete: Bool = false
    var dailyHistory: [String: Int] = [:]
    var lastDailyDate: String?
    var seenChapterIntros: [String] = []

    func metric(_ m: Metric) -> Int { metrics[m.rawValue] ?? 0 }

    mutating func add(_ m: Metric, _ amount: Int) {
        metrics[m.rawValue, default: 0] += amount
    }

    mutating func setMax(_ m: Metric, _ value: Int) {
        metrics[m.rawValue] = max(metrics[m.rawValue] ?? 0, value)
    }

    var totalStars: Int { levelStars.values.reduce(0, +) }
}
