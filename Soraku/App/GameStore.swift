import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class GameStore {
    private(set) var snapshot: GameSnapshot
    let content: CampaignContent

    @ObservationIgnored private let persistence: SnapshotPersistence
    @ObservationIgnored let audio: AudioService
    @ObservationIgnored let haptics: HapticsService
    @ObservationIgnored let motion: MotionService
    @ObservationIgnored private var saveScheduled = false

    init(persistence: SnapshotPersistence? = nil,
         audio: AudioService? = nil,
         haptics: HapticsService? = nil,
         motion: MotionService? = nil) {
        self.persistence = persistence ?? SwiftDataPersistence()
        self.audio = audio ?? AudioService()
        self.haptics = haptics ?? HapticsService()
        self.motion = motion ?? MotionService()
        self.content = ContentRepository.shared.content
        self.snapshot = self.persistence.load()
        ensureDefaults()
        applyServiceSettings()
    }

    private func ensureDefaults() {
        for cosmetic in content.cosmetics where cosmetic.isDefault {
            if !snapshot.unlockedCosmetics.contains(cosmetic.id) {
                snapshot.unlockedCosmetics.append(cosmetic.id)
            }
            if snapshot.equipped[cosmetic.type.rawValue] == nil {
                snapshot.equipped[cosmetic.type.rawValue] = cosmetic.id
            }
        }
        recomputeDerivedMetrics()
    }

    func bootstrap() {
        audio.configure()
        applyServiceSettings()
        motion.sensitivity = snapshot.settings.brushTiltSensitivity
    }

    private func applyServiceSettings() {
        let s = snapshot.settings
        audio.updateSettings(sound: s.soundEnabled, music: s.musicEnabled, ambience: s.ambienceEnabled, soundscape: equippedId(.sound))
        haptics.enabled = s.hapticsEnabled
        motion.sensitivity = s.brushTiltSensitivity
    }


    var settings: GameSettings { snapshot.settings }

    func updateSettings(_ transform: (inout GameSettings) -> Void) {
        transform(&snapshot.settings)
        applyServiceSettings()
        persist()
    }

    func completeOnboarding() {
        snapshot.onboardingComplete = true
        persist()
    }

    func resetTutorial() {
        snapshot.onboardingComplete = false
        persist()
    }

    func resetProgress() {
        var fresh = GameSnapshot()
        fresh.settings = snapshot.settings
        snapshot = fresh
        ensureDefaults()
        applyServiceSettings()
        persist()
    }


    var chapters: [ChapterDefinition] { content.chapters }

    func levels(in chapter: ChapterDefinition) -> [LevelDefinition] {
        chapter.levelIds.compactMap { content.levelsById[$0] }
    }

    func stars(for levelId: String) -> Int { snapshot.levelStars[levelId] ?? 0 }

    func isLevelUnlocked(_ level: LevelDefinition) -> Bool {
        guard let chapter = content.chaptersById[level.chapterId] else { return false }
        if !ProgressEngine.chapterUnlocked(chapter, snapshot: snapshot) { return false }
        if level.indexInChapter == 0 { return true }
        let previousId = chapter.levelIds[max(0, level.indexInChapter - 1)]
        return (snapshot.levelStars[previousId] ?? 0) > 0
    }

    func isChapterUnlocked(_ chapter: ChapterDefinition) -> Bool {
        ProgressEngine.chapterUnlocked(chapter, snapshot: snapshot)
    }

    func chapterStars(_ chapter: ChapterDefinition) -> Int {
        ProgressEngine.chapterStars(chapter, snapshot: snapshot)
    }

    func chapterCleared(_ chapter: ChapterDefinition) -> Bool {
        ProgressEngine.chapterCleared(chapter, snapshot: snapshot)
    }

    var totalStars: Int { snapshot.totalStars }
    var currency: Int { snapshot.currency }

    func nextPlayableLevel() -> LevelDefinition? {
        for chapter in content.chapters where isChapterUnlocked(chapter) {
            for level in levels(in: chapter) where isLevelUnlocked(level) {
                if stars(for: level.id) == 0 { return level }
            }
        }
        return content.chapters.first.flatMap { levels(in: $0).first }
    }


    func saveInProgress(levelId: String, inked: [String], records: [StrokeRecord]) {
        snapshot.inProgress = InProgressLevel(
            levelId: levelId,
            inkedSegments: inked,
            strokeRecords: records.map(SavedStrokeRecord.init)
        )
        scheduleSave()
    }

    func inProgress(for levelId: String) -> InProgressLevel? {
        guard let p = snapshot.inProgress, p.levelId == levelId else { return nil }
        return p
    }

    func clearInProgress() {
        snapshot.inProgress = nil
        scheduleSave()
    }

    func completeLevel(_ result: LevelRunResult, isDaily: Bool = false, dateKey: String? = nil) {
        let previous = snapshot.levelStars[result.levelId] ?? 0
        let newlyCleared = previous == 0 && result.cleared

        if result.cleared {
            snapshot.levelStars[result.levelId] = max(previous, result.stars)
            snapshot.currency += result.reward
            snapshot.add(.glyphsTraced, 1)
            snapshot.add(.totalStrokes, result.totalStrokes)
            snapshot.add(.calmBreaths, result.calmStrokes)
            snapshot.add(.perfectStrokes, result.perfectStrokes)
            if result.blotCount == 0 { snapshot.add(.blotFreeGlyphs, 1) }
            if newlyCleared && result.crossingGlyph { snapshot.add(.crossingGlyphs, 1) }
        }

        if isDaily, let dateKey {
            snapshot.dailyHistory[dateKey] = max(snapshot.dailyHistory[dateKey] ?? 0, result.stars)
            if newlyCleared || snapshot.lastDailyDate != dateKey {
                snapshot.add(.dailyCompleted, 1)
            }
            snapshot.lastDailyDate = dateKey
        }

        snapshot.inProgress = nil
        recomputeDerivedMetrics()

        if result.cleared {
            audio.playSeal()
            haptics.play(.success)
        }
        persist()
    }

    private func recomputeDerivedMetrics() {
        snapshot.metrics[Metric.starsEarned.rawValue] = snapshot.totalStars
        let cleared = content.chapters.filter { ProgressEngine.chapterCleared($0, snapshot: snapshot) }.count
        snapshot.metrics[Metric.chaptersCleared.rawValue] = cleared
        let nonDefault = snapshot.unlockedCosmetics.filter { id in
            content.cosmetics.first(where: { $0.id == id })?.isDefault == false
        }.count
        snapshot.metrics[Metric.cosmeticsUnlocked.rawValue] = nonDefault
        if let last = content.chapters.last, isChapterUnlocked(last) {
            snapshot.setMax(.reachedFinalChapter, 1)
        }
    }


    func addZenSeconds(_ seconds: Int) {
        guard seconds > 0 else { return }
        snapshot.add(.zenSeconds, seconds)
        scheduleSave()
    }

    func addTimePlayed(_ seconds: Int) {
        guard seconds > 0 else { return }
        snapshot.add(.timePlayedSeconds, seconds)
        scheduleSave()
    }


    func cosmetics(of kind: CosmeticKind) -> [CosmeticDefinition] {
        content.cosmetics.filter { $0.type == kind }.sorted { $0.cost < $1.cost }
    }

    func isUnlocked(_ cosmetic: CosmeticDefinition) -> Bool {
        snapshot.unlockedCosmetics.contains(cosmetic.id)
    }

    func isEquipped(_ cosmetic: CosmeticDefinition) -> Bool {
        snapshot.equipped[cosmetic.type.rawValue] == cosmetic.id
    }

    func equippedId(_ kind: CosmeticKind) -> String {
        snapshot.equipped[kind.rawValue] ?? cosmetics(of: kind).first?.id ?? ""
    }

    func equipped(_ kind: CosmeticKind) -> CosmeticDefinition? {
        content.cosmetics.first { $0.id == equippedId(kind) }
    }

    func canAfford(_ cosmetic: CosmeticDefinition) -> Bool {
        snapshot.currency >= cosmetic.cost
    }

    @discardableResult
    func unlock(_ cosmetic: CosmeticDefinition) -> Bool {
        guard !isUnlocked(cosmetic), canAfford(cosmetic) else { return false }
        snapshot.currency -= cosmetic.cost
        snapshot.unlockedCosmetics.append(cosmetic.id)
        recomputeDerivedMetrics()
        audio.playSoft()
        haptics.play(.success)
        persist()
        return true
    }

    func equip(_ cosmetic: CosmeticDefinition) {
        guard isUnlocked(cosmetic) else { return }
        snapshot.equipped[cosmetic.type.rawValue] = cosmetic.id
        applyServiceSettings()
        haptics.play(.selection)
        persist()
    }


    func questStates() -> [QuestState] {
        ProgressEngine.questStates(snapshot: snapshot, quests: content.quests)
    }

    @discardableResult
    func claimQuest(_ state: QuestState) -> Bool {
        guard state.isComplete, !state.claimed else { return false }
        snapshot.claimedQuests.append(state.definition.id)
        snapshot.currency += state.definition.reward
        audio.playChime()
        haptics.play(.success)
        persist()
        return true
    }

    func achievementStates() -> [AchievementState] {
        ProgressEngine.achievementStates(snapshot: snapshot, achievements: content.achievements)
    }


    func hasSeenIntro(_ chapter: ChapterDefinition) -> Bool {
        snapshot.seenChapterIntros.contains(chapter.id)
    }

    func markIntroSeen(_ chapter: ChapterDefinition) {
        guard !snapshot.seenChapterIntros.contains(chapter.id) else { return }
        snapshot.seenChapterIntros.append(chapter.id)
        persist()
    }


    func dailyStars(_ dateKey: String) -> Int { snapshot.dailyHistory[dateKey] ?? 0 }


    func persist() {
        persistence.save(snapshot)
    }

    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self.saveScheduled = false
            self.persist()
        }
    }
}
