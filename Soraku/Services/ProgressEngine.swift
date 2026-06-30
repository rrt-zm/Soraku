import Foundation

struct QuestState: Identifiable, Hashable {
    let definition: QuestDefinition
    let progress: Int
    let claimed: Bool
    var id: String { definition.id }
    var isComplete: Bool { progress >= definition.target }
    var fraction: Double { min(1, Double(progress) / Double(max(1, definition.target))) }
}

struct AchievementState: Identifiable, Hashable {
    let definition: AchievementDefinition
    let progress: Int
    var id: String { definition.id }
    var unlocked: Bool { progress >= definition.target }
    var fraction: Double { min(1, Double(progress) / Double(max(1, definition.target))) }
}

enum ProgressEngine {
    static func questStates(snapshot: GameSnapshot, quests: [QuestDefinition]) -> [QuestState] {
        quests.map { def in
            QuestState(
                definition: def,
                progress: snapshot.metrics[def.metric] ?? 0,
                claimed: snapshot.claimedQuests.contains(def.id)
            )
        }
    }

    static func achievementStates(snapshot: GameSnapshot, achievements: [AchievementDefinition]) -> [AchievementState] {
        achievements.map { def in
            AchievementState(definition: def, progress: snapshot.metrics[def.metric] ?? 0)
        }
    }

    static func chapterCleared(_ chapter: ChapterDefinition, snapshot: GameSnapshot) -> Bool {
        chapter.levelIds.allSatisfy { (snapshot.levelStars[$0] ?? 0) > 0 }
    }

    static func chapterStars(_ chapter: ChapterDefinition, snapshot: GameSnapshot) -> Int {
        chapter.levelIds.reduce(0) { $0 + (snapshot.levelStars[$1] ?? 0) }
    }

    static func chapterUnlocked(_ chapter: ChapterDefinition, snapshot: GameSnapshot) -> Bool {
        snapshot.totalStars >= chapter.unlockStars
    }
}
