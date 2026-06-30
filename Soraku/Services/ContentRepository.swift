import Foundation

struct CampaignContent {
    let chapters: [ChapterDefinition]
    let levels: [LevelDefinition]
    let cosmetics: [CosmeticDefinition]
    let quests: [QuestDefinition]
    let achievements: [AchievementDefinition]
    let levelsById: [String: LevelDefinition]
    let chaptersById: [String: ChapterDefinition]
    let validationReport: ContentValidationReport
}

struct ContentValidationReport {
    let totalLevels: Int
    let solvableLevels: Int
    let mismatchedLevels: [String]
    var allSolvable: Bool { mismatchedLevels.isEmpty }
}

enum ContentLoaderError: Error { case missing(String) }

final class ContentRepository {
    static let shared = ContentRepository()

    private(set) lazy var content: CampaignContent = Self.load()

    private struct ChaptersFile: Codable { let chapters: [ChapterDefinition] }
    private struct LevelsFile: Codable { let levels: [LevelDefinition] }
    private struct CosmeticsFile: Codable { let cosmetics: [CosmeticDefinition] }
    private struct QuestsFile: Codable { let quests: [QuestDefinition] }
    private struct AchievementsFile: Codable { let achievements: [AchievementDefinition] }

    private static func data(_ name: String) -> Data {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "json"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Resources")
        ].compactMap { $0 }
        for url in candidates {
            if let d = try? Data(contentsOf: url) { return d }
        }
        return Data("{}".utf8)
    }

    private static func load() -> CampaignContent {
        let decoder = JSONDecoder()
        let chapters = (try? decoder.decode(ChaptersFile.self, from: data("chapters")))?.chapters ?? []
        let levels = (try? decoder.decode(LevelsFile.self, from: data("levels")))?.levels ?? []
        let cosmetics = (try? decoder.decode(CosmeticsFile.self, from: data("cosmetics")))?.cosmetics ?? []
        let quests = (try? decoder.decode(QuestsFile.self, from: data("quests")))?.quests ?? []
        let achievements = (try? decoder.decode(AchievementsFile.self, from: data("achievements")))?.achievements ?? []

        var mismatches: [String] = []
        var solvable = 0
        for level in levels {
            let graph = GlyphGraph(level: level)
            if graph.minimumStrokes == level.requiredStrokes {
                solvable += 1
            } else {
                mismatches.append(level.id)
            }
        }

        let report = ContentValidationReport(totalLevels: levels.count, solvableLevels: solvable, mismatchedLevels: mismatches)

        var byLevel: [String: LevelDefinition] = [:]
        for l in levels { byLevel[l.id] = l }
        var byChapter: [String: ChapterDefinition] = [:]
        for c in chapters { byChapter[c.id] = c }

        return CampaignContent(
            chapters: chapters.sorted { $0.index < $1.index },
            levels: levels,
            cosmetics: cosmetics,
            quests: quests,
            achievements: achievements,
            levelsById: byLevel,
            chaptersById: byChapter,
            validationReport: report
        )
    }

    func level(_ id: String) -> LevelDefinition? { content.levelsById[id] }
    func chapter(_ id: String) -> ChapterDefinition? { content.chaptersById[id] }
    func levels(in chapter: ChapterDefinition) -> [LevelDefinition] {
        chapter.levelIds.compactMap { content.levelsById[$0] }
    }

    func dailyLevel(for date: Date) -> LevelDefinition {
        let levels = content.levels
        guard !levels.isEmpty else {
            fatalError("Soraku campaign content is missing")
        }
        let key = Self.dayNumber(date)
        return levels[key % levels.count]
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func dayNumber(_ date: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return (comps.year ?? 2026) * 372 + (comps.month ?? 1) * 31 + (comps.day ?? 1)
    }
}
